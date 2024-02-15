// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {
    Helpers,
    Context,
    Errors,
    Constants,
    DataTypes,
    Events,
    Address,
    GnosisSafeMath,
    Enum,
    IGnosisSafe,
    IGnosisSafeProxy
} from "./Helpers.sol";
import {ReentrancyGuard} from "@openzeppelin/security/ReentrancyGuard.sol";

/// @title Keyper Module
/// @custom:security-contact general@palmeradao.xyz
contract KeyperModule is Auth, ReentrancyGuard, Helpers {
    using GnosisSafeMath for uint256;
    using Address for address;

    /// @dev Definition of Safe module
    string public constant NAME = "Keyper Module";
    string public constant VERSION = "0.2.0";
    /// @dev Control Nonce of the module
    uint256 public nonce;
    /// @dev indexId of the squad
    uint256 public indexId;
    /// @dev Max Depth Tree Limit
    uint256 public maxDepthTreeLimit;
    /// @dev Safe contracts
    address public immutable masterCopy;
    address public immutable proxyFactory;
    /// @dev RoleAuthority
    address public rolesAuthority;
    /// @dev Array of Orgs (based on Hash(DAO's name) of the Org)
    bytes32[] private orgHash;
    /// @dev Index of Squad
    /// bytes32: Hash(DAO's name) -> uint256: ID's Squads
    mapping(bytes32 => uint256[]) public indexSquad;
    /// @dev Depth Tree Limit
    /// bytes32: Hash(DAO's name) -> uint256: Depth Tree Limit
    mapping(bytes32 => uint256) public depthTreeLimit;
    /// @dev Hash(DAO's name) -> Squads
    /// bytes32: Hash(DAO's name).   uint256:SquadId.   Squad: Squad Info
    mapping(bytes32 => mapping(uint256 => DataTypes.Squad)) public squads;

    /// @dev Modifier for Validate if Org/Squad Exist or SuperSafeNotRegistered Not
    /// @param squad ID of the squad
    modifier SquadRegistered(uint256 squad) {
        if (squads[getOrgBySquad(squad)][squad].safe == address(0)) {
            revert Errors.SquadNotRegistered(squad);
        }
        _;
    }

    /// @dev Modifier for Validate if safe caller is Registered
    /// @param safe Safe address
    modifier SafeRegistered(address safe) {
        if (
            (safe == address(0)) || safe == Constants.SENTINEL_ADDRESS
                || !isSafe(safe)
        ) {
            revert Errors.InvalidGnosisSafe(safe);
        } else if (!isSafeRegistered(safe)) {
            revert Errors.SafeNotRegistered(safe);
        }
        _;
    }

    /// @dev Modifier for Validate if the address is a Gnosis Safe Multisig Wallet and Root Safe
    /// @param safe Address of the Gnosis Safe Multisig Wallet
    modifier IsRootSafe(address safe) {
        if (
            (safe == address(0)) || safe == Constants.SENTINEL_ADDRESS
                || !isSafe(safe)
        ) {
            revert Errors.InvalidGnosisSafe(safe);
        } else if (!isSafeRegistered(safe)) {
            revert Errors.SafeNotRegistered(safe);
        } else if (
            squads[getOrgHashBySafe(safe)][getSquadIdBySafe(
                getOrgHashBySafe(safe), safe
            )].tier != DataTypes.Tier.ROOT
        ) {
            revert Errors.InvalidGnosisRootSafe(safe);
        }
        _;
    }

    constructor(
        address masterCopyAddress,
        address proxyFactoryAddress,
        address authorityAddress,
        uint256 maxDepthTreeLimitInitial
    ) Auth(address(0), Authority(authorityAddress)) {
        if (
            (authorityAddress == address(0)) || !masterCopyAddress.isContract()
                || !proxyFactoryAddress.isContract()
        ) revert Errors.InvalidAddressProvided();

        masterCopy = masterCopyAddress;
        proxyFactory = proxyFactoryAddress;
        rolesAuthority = authorityAddress;
        /// Index of Squads starts in 1 Always
        indexId = 1;
        maxDepthTreeLimit = maxDepthTreeLimitInitial;
    }

    /// @notice Calls execTransaction of the safe with custom checks on owners rights
    /// @param org ID's Organization
    /// @param superSafe Safe super address
    /// @param targetSafe Safe target address
    /// @param to Address to which the transaction is being sent
    /// @param value Value (ETH) that is being sent with the transaction
    /// @param data Data payload of the transaction
    /// @param operation kind of operation (call or delegatecall)
    /// @param signatures Packed signatures data (v, r, s)
    /// @return result true if transaction was successful.
    function execTransactionOnBehalf(
        bytes32 org,
        address superSafe, // can be root or super safe
        address targetSafe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        bytes memory signatures
    )
        external
        payable
        nonReentrant
        SafeRegistered(superSafe)
        SafeRegistered(targetSafe)
        Denied(org, to)
        returns (bool result)
    {
        address caller = _msgSender();
        // Caller is Safe Lead: bypass check of signatures
        // Caller is another kind of wallet: check if it has the corrects signatures of the root/super safe
        if (!isSafeLead(getSquadIdBySafe(org, targetSafe), caller)) {
            // Check if caller is a superSafe of the target safe (checking with isTreeMember because is the same method!!)
            if (hasNotPermissionOverTarget(superSafe, org, targetSafe)) {
                revert Errors.NotAuthorizedExecOnBehalf();
            }
            // Caller is a safe then check caller's safe signatures.
            bytes memory keyperTxHashData = encodeTransactionData(
                /// Keyper Info
                org,
                superSafe,
                targetSafe,
                /// Transaction info
                to,
                value,
                data,
                operation,
                /// Signature info
                nonce
            );
            /// Verify Collision of Nonce with multiple txs in the same range of time, study to use a nonce per org

            IGnosisSafe gnosisLeadSafe = IGnosisSafe(superSafe);
            bytes memory sortedSignatures = processAndSortSignatures(
                signatures,
                keccak256(keyperTxHashData),
                gnosisLeadSafe.getOwners()
            );
            gnosisLeadSafe.checkSignatures(
                keccak256(keyperTxHashData), keyperTxHashData, sortedSignatures
            );
        }
        /// Increase nonce and execute transaction.
        nonce++;
        /// Execute transaction from target safe
        IGnosisSafe gnosisTargetSafe = IGnosisSafe(targetSafe);
        result = gnosisTargetSafe.execTransactionFromModule(
            to, value, data, operation
        );

        if (!result) revert Errors.TxOnBehalfExecutedFailed();
        emit Events.TxOnBehalfExecuted(
            org, caller, superSafe, targetSafe, result
        );
    }

    /// @notice This function will allow Safe Lead & Safe Lead modify only roles
    /// @notice to to add owner and set a threshold without passing by normal multisig check
    /// @dev For instance addOwnerWithThreshold can be called by Safe Lead & Safe Lead modify only roles
    /// @param ownerAdded Address of the owner to be added
    /// @param threshold Threshold of the Gnosis Safe Multisig Wallet
    /// @param targetSafe Address of the Gnosis Safe Multisig Wallet
    /// @param org Hash(DAO's name)
    function addOwnerWithThreshold(
        address ownerAdded,
        uint256 threshold,
        address targetSafe,
        bytes32 org
    )
        external
        validAddress(ownerAdded)
        SafeRegistered(targetSafe)
        requiresAuth
    {
        address caller = _msgSender();
        if (hasNotPermissionOverTarget(caller, org, targetSafe)) {
            revert Errors.NotAuthorizedAddOwnerWithThreshold();
        }

        IGnosisSafe gnosisTargetSafe = IGnosisSafe(targetSafe);
        /// If the owner is already an owner
        if (gnosisTargetSafe.isOwner(ownerAdded)) {
            revert Errors.OwnerAlreadyExists();
        }

        bytes memory data = abi.encodeWithSelector(
            IGnosisSafe.addOwnerWithThreshold.selector, ownerAdded, threshold
        );
        /// Execute transaction from target safe
        _executeModuleTransaction(targetSafe, data);
    }

    /// @notice This function will allow User Lead/Super/Root to remove an owner
    /// @dev For instance of Remove Owner of Gnosis Safe, the user lead/super/root can remove an owner without passing by normal multisig check signature
    /// @param prevOwner Address of the previous owner
    /// @param ownerRemoved Address of the owner to be removed
    /// @param threshold Threshold of the Gnosis Safe Multisig Wallet
    /// @param targetSafe Address of the Gnosis Safe Multisig Wallet
    /// @param org Hash(DAO's name)
    function removeOwner(
        address prevOwner,
        address ownerRemoved,
        uint256 threshold,
        address targetSafe,
        bytes32 org
    ) external SafeRegistered(targetSafe) requiresAuth {
        address caller = _msgSender();
        if (
            prevOwner == address(0) || ownerRemoved == address(0)
                || prevOwner == Constants.SENTINEL_ADDRESS
                || ownerRemoved == Constants.SENTINEL_ADDRESS
        ) {
            revert Errors.ZeroAddressProvided();
        }

        if (hasNotPermissionOverTarget(caller, org, targetSafe)) {
            revert Errors.NotAuthorizedRemoveOwner();
        }
        IGnosisSafe gnosisTargetSafe = IGnosisSafe(targetSafe);
        /// if Owner Not found
        if (!gnosisTargetSafe.isOwner(ownerRemoved)) {
            revert Errors.OwnerNotFound();
        }

        bytes memory data = abi.encodeWithSelector(
            IGnosisSafe.removeOwner.selector, prevOwner, ownerRemoved, threshold
        );

        /// Execute transaction from target safe
        _executeModuleTransaction(targetSafe, data);
    }

    /// @notice Give user roles
    /// @dev Call must come from the root safe
    /// @param role Role to be assigned
    /// @param user User that will have specific role (Can be EAO or safe)
    /// @param squad Safe squad which will have the user permissions on
    /// @param enabled Enable or disable the role
    function setRole(
        DataTypes.Role role,
        address user,
        uint256 squad,
        bool enabled
    ) external validAddress(user) IsRootSafe(_msgSender()) requiresAuth {
        address caller = _msgSender();
        if (
            role == DataTypes.Role.ROOT_SAFE
                || role == DataTypes.Role.SUPER_SAFE
        ) {
            revert Errors.SetRoleForbidden(role);
        }
        if (!isRootSafeOf(caller, squad)) {
            revert Errors.NotAuthorizedSetRoleAnotherTree();
        }
        DataTypes.Squad storage safeSquad =
            squads[getOrgHashBySafe(caller)][squad];
        // Check if squad is part of the caller org
        if (
            role == DataTypes.Role.SAFE_LEAD
                || role == DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY
                || role == DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY
        ) {
            // Update squad/org lead
            safeSquad.lead = user;
        }
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        _authority.setUserRole(user, uint8(role), enabled);
    }

    /// @notice Register an organization
    /// @dev Call has to be done from a safe transaction
    /// @param daoName String with of the org (This name will be hashed into smart contract)
    function registerOrg(string calldata daoName)
        external
        IsGnosisSafe(_msgSender())
        returns (uint256 squadId)
    {
        bytes32 name = keccak256(abi.encodePacked(daoName));
        address caller = _msgSender();
        squadId = _createOrgOrRoot(daoName, caller, caller);
        orgHash.push(name);
        // Setting level by Default
        depthTreeLimit[name] = 8;

        emit Events.OrganizationCreated(caller, name, daoName);
    }

    /// @notice Call has to be done from another root safe to the organization
    /// @dev Call has to be done from a safe transaction
    /// @param newRootSafe Address of new Root Safe
    /// @param name string name of the squad
    function createRootSafeSquad(address newRootSafe, string calldata name)
        external
        IsGnosisSafe(newRootSafe)
        IsRootSafe(_msgSender())
        requiresAuth
        returns (uint256 squadId)
    {
        address caller = _msgSender();
        bytes32 org = getOrgHashBySafe(caller);
        uint256 newIndex = indexId;
        squadId = _createOrgOrRoot(name, caller, newRootSafe);
        // Setting level by default
        depthTreeLimit[org] = 8;

        emit Events.RootSafeSquadCreated(
            org, newIndex, caller, newRootSafe, name
        );
    }

    /// @notice Add a squad to an organization/squad
    /// @dev Call coming from the squad safe
    /// @param superSafe address of the superSafe
    /// @param name string name of the squad
    function addSquad(uint256 superSafe, string memory name)
        external
        SquadRegistered(superSafe)
        IsGnosisSafe(_msgSender())
        returns (uint256 squadId)
    {
        // check the name of squad is not empty
        if (bytes(name).length == 0) revert Errors.EmptyName();
        bytes32 org = getOrgBySquad(superSafe);
        address caller = _msgSender();
        if (isSafeRegistered(caller)) {
            revert Errors.SafeAlreadyRegistered(caller);
        }
        // check to verify if the caller is already exist in the org
        if (isTreeMember(superSafe, getSquadIdBySafe(org, caller))) {
            revert Errors.SquadAlreadyRegistered();
        }
        // check if the superSafe Reached Depth Tree Limit
        if (isLimitLevel(superSafe)) {
            revert Errors.TreeDepthLimitReached(depthTreeLimit[org]);
        }
        /// Create a new squad
        DataTypes.Squad storage newSquad = squads[org][indexId];
        /// Add to org root/squad
        DataTypes.Squad storage superSafeOrgSquad = squads[org][superSafe];
        /// Add child to superSafe
        squadId = indexId;
        superSafeOrgSquad.child.push(squadId);

        newSquad.safe = caller;
        newSquad.name = name;
        newSquad.superSafe = superSafe;
        indexSquad[org].push(squadId);
        indexId++;
        /// Give Role SuperSafe
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        if (
            (
                !_authority.doesUserHaveRole(
                    superSafeOrgSquad.safe, uint8(DataTypes.Role.SUPER_SAFE)
                )
            ) && (superSafeOrgSquad.child.length > 0)
        ) {
            _authority.setUserRole(
                superSafeOrgSquad.safe, uint8(DataTypes.Role.SUPER_SAFE), true
            );
        }

        emit Events.SquadCreated(
            org, squadId, newSquad.lead, caller, superSafe, name
        );
    }

    /// @notice Remove squad and reasign all child to the superSafe
    /// @dev All actions will be driven based on the caller of the method, and args
    /// @param squad address of the squad to be removed
    function removeSquad(uint256 squad)
        public
        SafeRegistered(_msgSender())
        requiresAuth
    {
        address caller = _msgSender();
        bytes32 org = getOrgHashBySafe(caller);
        uint256 callerSafe = getSquadIdBySafe(org, caller);
        uint256 rootSafe = getRootSafe(squad);
        /// Avoid Replay attack
        if (squads[org][squad].tier == DataTypes.Tier.REMOVED) {
            revert Errors.SquadAlreadyRemoved();
        }
        // SuperSafe usecase : Check caller is superSafe of the squad
        if ((!isRootSafeOf(caller, squad)) && (!isSuperSafe(callerSafe, squad)))
        {
            revert Errors.NotAuthorizedAsNotRootOrSuperSafe();
        }
        DataTypes.Squad storage _squad = squads[org][squad];
        // Check if the squad is Root Safe and has child
        if (
            ((_squad.tier == DataTypes.Tier.ROOT) || (_squad.superSafe == 0))
                && (_squad.child.length > 0)
        ) {
            revert Errors.CannotRemoveSquadBeforeRemoveChild(
                _squad.child.length
            );
        }

        // superSafe is either an org or a squad
        DataTypes.Squad storage superSafe = squads[org][_squad.superSafe];

        /// Remove child from superSafe
        for (uint256 i = 0; i < superSafe.child.length; ++i) {
            if (superSafe.child[i] == squad) {
                superSafe.child[i] = superSafe.child[superSafe.child.length - 1];
                superSafe.child.pop();
                break;
            }
        }
        // Handle child from removed squad
        for (uint256 i = 0; i < _squad.child.length; ++i) {
            // Add removed squad child to superSafe
            superSafe.child.push(_squad.child[i]);
            DataTypes.Squad storage childrenSquad = squads[org][_squad.child[i]];
            // Update children squad superSafe reference
            childrenSquad.superSafe = _squad.superSafe;
        }
        /// we guarantee the child was moving to another SuperSafe in the Org
        /// and validate after in the Disconnect Safe method
        _squad.child = new uint256[](0);

        // Revoke roles to squad
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        _authority.setUserRole(
            _squad.safe, uint8(DataTypes.Role.SUPER_SAFE), false
        );
        // Disable safe lead role
        disableSafeLeadRoles(_squad.safe);

        // Store the name before to delete the Squad
        emit Events.SquadRemoved(
            org, squad, superSafe.lead, caller, _squad.superSafe, _squad.name
        );
        // Assign the with Root Safe (because is not part of the Tree)
        // If the Squad is not Root Safe, pass to depend on Root Safe directly
        _squad.superSafe = _squad.superSafe == 0 ? 0 : rootSafe;
        _squad.tier = _squad.tier == DataTypes.Tier.ROOT
            ? DataTypes.Tier.ROOT
            : DataTypes.Tier.REMOVED;
    }

    /// @notice Disconnect Safe of a squad
    /// @dev Disconnect Safe of a squad, Call must come from the root safe
    /// @param squad address of the squad to be updated
    function disconnectSafe(uint256 squad)
        external
        IsRootSafe(_msgSender())
        SquadRegistered(squad)
        requiresAuth
    {
        address caller = _msgSender();
        bytes32 org = getOrgHashBySafe(caller);
        uint256 rootSafe = getSquadIdBySafe(org, caller);
        DataTypes.Squad memory disconnectSquad = squads[org][squad];
        /// RootSafe usecase : Check if the squad is Member of the Tree of the caller (rootSafe)
        if (
            (
                (!isRootSafeOf(caller, squad))
                    && (disconnectSquad.tier != DataTypes.Tier.REMOVED)
            )
                || (
                    (!isPendingRemove(rootSafe, squad))
                        && (disconnectSquad.tier == DataTypes.Tier.REMOVED)
                )
        ) {
            revert Errors.NotAuthorizedDisconnectChildrenSquad();
        }
        /// In case Root Safe Disconnect Safe without removeSquad Before
        if (disconnectSquad.tier != DataTypes.Tier.REMOVED) {
            removeSquad(squad);
        }
        // Disconnect Safe
        _exitSafe(squad);
        if (indexSquad[org].length == 0) removeOrg(org);
    }

    /// @notice Remove whole tree of a RootSafe
    /// @dev Remove whole tree of a RootSafe
    function removeWholeTree() external IsRootSafe(_msgSender()) requiresAuth {
        address caller = _msgSender();
        bytes32 org = getOrgHashBySafe(caller);
        uint256 rootSafe = getSquadIdBySafe(org, caller);
        uint256[] memory _indexSquad = getTreeMember(rootSafe, indexSquad[org]);
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        for (uint256 j = 0; j < _indexSquad.length; j++) {
            uint256 squad = _indexSquad[j];
            DataTypes.Squad memory _squad = squads[org][squad];
            // Revoke roles to squad
            _authority.setUserRole(
                _squad.safe, uint8(DataTypes.Role.SUPER_SAFE), false
            );
            // Disable safe lead role
            disableSafeLeadRoles(squads[org][squad].safe);
            _exitSafe(squad);
        }
        // After Disconnect Root Safe
        emit Events.WholeTreeRemoved(
            org, rootSafe, caller, squads[org][rootSafe].name
        );
        _exitSafe(rootSafe);
        if (indexSquad[org].length == 0) removeOrg(org);
    }

    /// @notice Method to Promete a squad to Root Safe of an Org to Root Safe
    /// @dev Method to Promete a squad to Root Safe of an Org to Root Safe
    /// @param squad address of the squad to be updated
    function promoteRoot(uint256 squad)
        external
        IsRootSafe(_msgSender())
        SquadRegistered(squad)
        requiresAuth
    {
        bytes32 org = getOrgBySquad(squad);
        address caller = _msgSender();
        /// RootSafe usecase : Check if the squad is Member of the Tree of the caller (rootSafe)
        if (!isRootSafeOf(caller, squad)) {
            revert Errors.NotAuthorizedUpdateNonChildrenSquad();
        }
        DataTypes.Squad storage newRootSafe = squads[org][squad];
        /// Check if the squad is a Super Safe, and an Direct Children of thr Root Safe
        if (
            (newRootSafe.child.length <= 0)
                || (!isSuperSafe(getSquadIdBySafe(org, caller), squad))
        ) {
            revert Errors.NotAuthorizedUpdateNonSuperSafe();
        }
        /// Give Role RootSafe if not have it
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        _authority.setUserRole(
            newRootSafe.safe, uint8(DataTypes.Role.ROOT_SAFE), true
        );
        // Update Tier
        newRootSafe.tier = DataTypes.Tier.ROOT;
        // Update Root Safe
        newRootSafe.lead = address(0);
        newRootSafe.superSafe = 0;
        emit Events.RootSafePromoted(
            org, squad, caller, newRootSafe.safe, newRootSafe.name
        );
    }

    /// @notice update superSafe of a squad
    /// @dev Update the superSafe of a squad with a new superSafe, Call must come from the root safe
    /// @param squad address of the squad to be updated
    /// @param newSuper address of the new superSafe
    function updateSuper(uint256 squad, uint256 newSuper)
        external
        IsRootSafe(_msgSender())
        SquadRegistered(newSuper)
        requiresAuth
    {
        bytes32 org = getOrgBySquad(squad);
        address caller = _msgSender();
        /// RootSafe usecase : Check if the squad is Member of the Tree of the caller (rootSafe)
        if (!isRootSafeOf(caller, squad)) {
            revert Errors.NotAuthorizedUpdateNonChildrenSquad();
        }
        // Validate are the same org
        if (org != getOrgBySquad(newSuper)) {
            revert Errors.NotAuthorizedUpdateSquadToOtherOrg();
        }
        /// Check if the new Super Safe is Reached Depth Tree Limit
        if (isLimitLevel(newSuper)) {
            revert Errors.TreeDepthLimitReached(depthTreeLimit[org]);
        }
        DataTypes.Squad storage _squad = squads[org][squad];
        /// SuperSafe is either an Org or a Squad
        DataTypes.Squad storage oldSuper = squads[org][_squad.superSafe];

        /// Remove child from superSafe
        for (uint256 i = 0; i < oldSuper.child.length; ++i) {
            if (oldSuper.child[i] == squad) {
                oldSuper.child[i] = oldSuper.child[oldSuper.child.length - 1];
                oldSuper.child.pop();
                break;
            }
        }
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        /// Revoke SuperSafe and SafeLead if don't have any child, and is not organization
        if (oldSuper.child.length == 0) {
            _authority.setUserRole(
                oldSuper.safe, uint8(DataTypes.Role.SUPER_SAFE), false
            );
            /// TODO: verify if the oldSuper need or not the Safe Lead role (after MVP)
        }

        /// Update squad superSafe
        _squad.superSafe = newSuper;
        DataTypes.Squad storage newSuperSquad = squads[org][newSuper];
        /// Add squad to new superSafe
        /// Give Role SuperSafe if not have it
        if (
            !_authority.doesUserHaveRole(
                newSuperSquad.safe, uint8(DataTypes.Role.SUPER_SAFE)
            )
        ) {
            _authority.setUserRole(
                newSuperSquad.safe, uint8(DataTypes.Role.SUPER_SAFE), true
            );
        }
        newSuperSquad.child.push(squad);
        emit Events.SquadSuperUpdated(
            org,
            squad,
            _squad.lead,
            caller,
            getSquadIdBySafe(org, oldSuper.safe),
            newSuper
        );
    }

    /// @dev Method to update Depth Tree Limit
    /// @param newLimit new Depth Tree Limit
    function updateDepthTreeLimit(uint256 newLimit)
        external
        IsRootSafe(_msgSender())
        requiresAuth
    {
        address caller = _msgSender();
        bytes32 org = getOrgHashBySafe(caller);
        uint256 rootSafe = getSquadIdBySafe(org, caller);
        if ((newLimit > maxDepthTreeLimit) || (newLimit <= depthTreeLimit[org]))
        {
            revert Errors.InvalidLimit();
        }
        emit Events.NewLimitLevel(
            org, rootSafe, caller, depthTreeLimit[org], newLimit
        );
        depthTreeLimit[org] = newLimit;
    }

    /// List of the Methods of DenyHelpers
    /// Any changes in this five methods, must be validate into the abstract contract DenyHelper

    /// @dev Funtion to Add Wallet to the List based on Approach of Safe Contract - Owner Manager
    /// @param users Array of Address of the Wallet to be added to the List
    function addToList(address[] memory users)
        external
        IsRootSafe(_msgSender())
        requiresAuth
    {
        if (users.length == 0) revert Errors.ZeroAddressProvided();
        bytes32 org = getOrgHashBySafe(_msgSender());
        if (!allowFeature[org] && !denyFeature[org]) {
            revert Errors.DenyHelpersDisabled();
        }
        address currentWallet = Constants.SENTINEL_ADDRESS;
        for (uint256 i = 0; i < users.length; ++i) {
            address wallet = users[i];
            if (
                wallet == address(0) || wallet == Constants.SENTINEL_ADDRESS
                    || wallet == address(this) || currentWallet == wallet
            ) revert Errors.InvalidAddressProvided();
            // Avoid duplicate wallet
            if (listed[org][wallet] != address(0)) {
                revert Errors.UserAlreadyOnList();
            }
            // Add wallet to List
            listed[org][currentWallet] = wallet;
            currentWallet = wallet;
        }
        listed[org][currentWallet] = Constants.SENTINEL_ADDRESS;
        listCount[org] += users.length;
        emit Events.AddedToList(users);
    }

    /// @dev Function to Drop Wallet from the List  based on Approach of Safe Contract - Owner Manager
    /// @param user Array of Address of the Wallet to be dropped of the List
    function dropFromList(address user)
        external
        validAddress(user)
        IsRootSafe(_msgSender())
        requiresAuth
    {
        bytes32 org = getOrgHashBySafe(_msgSender());
        if (!allowFeature[org] && !denyFeature[org]) {
            revert Errors.DenyHelpersDisabled();
        }
        if (listCount[org] == 0) revert Errors.ListEmpty();
        if (!isListed(org, user)) revert Errors.InvalidAddressProvided();
        address prevUser = getPrevUser(org, user);
        listed[org][prevUser] = listed[org][user];
        listed[org][user] = address(0);
        listCount[org] = listCount[org] > 1 ? listCount[org].sub(1) : 0;
        emit Events.DroppedFromList(user);
    }

    /// @dev Method to Enable Allowlist
    function enableAllowlist() external IsRootSafe(_msgSender()) requiresAuth {
        bytes32 org = getOrgHashBySafe(_msgSender());
        allowFeature[org] = true;
        denyFeature[org] = false;
    }

    /// @dev Method to Enable Allowlist
    function enableDenylist() external IsRootSafe(_msgSender()) requiresAuth {
        bytes32 org = getOrgHashBySafe(_msgSender());
        allowFeature[org] = false;
        denyFeature[org] = true;
    }

    /// @dev Method to Disable All
    function disableDenyHelper()
        external
        IsRootSafe(_msgSender())
        requiresAuth
    {
        bytes32 org = getOrgHashBySafe(_msgSender());
        allowFeature[org] = false;
        denyFeature[org] = false;
    }

    // List of Helpers

    /// @notice Get all the information about a squad
    /// @dev Method for getting all info of a squad
    /// @param squad uint256 of the squad
    /// @return all the information about a squad
    function getSquadInfo(uint256 squad)
        public
        view
        SquadRegistered(squad)
        returns (
            DataTypes.Tier,
            string memory,
            address,
            address,
            uint256[] memory,
            uint256
        )
    {
        bytes32 org = getOrgBySquad(squad);
        return (
            squads[org][squad].tier,
            squads[org][squad].name,
            squads[org][squad].lead,
            squads[org][squad].safe,
            squads[org][squad].child,
            squads[org][squad].superSafe
        );
    }

    /// @notice This function checks that caller has permission (as Root/Super/Lead safe) of the target safe
    /// @param caller Caller's address
    /// @param org Hash(DAO's name)
    /// @param targetSafe Address of the target Gnosis Safe Multisig Wallet
    function hasNotPermissionOverTarget(
        address caller,
        bytes32 org,
        address targetSafe
    ) public view returns (bool hasPermission) {
        hasPermission = !isRootSafeOf(caller, getSquadIdBySafe(org, targetSafe))
            && !isSuperSafe(
                getSquadIdBySafe(org, caller), getSquadIdBySafe(org, targetSafe)
            ) && !isSafeLead(getSquadIdBySafe(org, targetSafe), caller);
        return hasPermission;
    }

    /// @notice check if the organisation is registered
    /// @param org address
    /// @return bool
    function isOrgRegistered(bytes32 org) public view returns (bool) {
        if (indexSquad[org].length == 0 || org == bytes32(0)) return false;
        return true;
    }

    /// @notice Check if the address, is a rootSafe of the squad within an organization
    /// @param squad ID's of the child squad/safe
    /// @param root address of Root Safe of the squad
    /// @return bool
    function isRootSafeOf(address root, uint256 squad)
        public
        view
        SquadRegistered(squad)
        returns (bool)
    {
        if (root == address(0) || squad == 0) return false;
        bytes32 org = getOrgBySquad(squad);
        uint256 rootSafe = getSquadIdBySafe(org, root);
        if (rootSafe == 0) return false;
        return (
            (squads[org][rootSafe].tier == DataTypes.Tier.ROOT)
                && (isTreeMember(rootSafe, squad))
        );
    }

    /// @notice Check if the squad is a Is Tree Member of another squad
    /// @param superSafe ID's of the superSafe
    /// @param squad ID's of the squad
    /// @return isMember
    function isTreeMember(uint256 superSafe, uint256 squad)
        public
        view
        returns (bool isMember)
    {
        if (superSafe == 0 || squad == 0) return false;
        bytes32 org = getOrgBySquad(superSafe);
        DataTypes.Squad memory childSquad = squads[org][squad];
        if (childSquad.safe == address(0)) return false;
        if (superSafe == squad) return true;
        (isMember,,) = _seekMember(superSafe, squad);
    }

    /// @dev Method to validate if is Depth Tree Limit
    /// @param superSafe ID's of Safe
    /// @return bool
    function isLimitLevel(uint256 superSafe) public view returns (bool) {
        if ((superSafe == 0) || (superSafe > indexId)) return false;
        bytes32 org = getOrgBySquad(superSafe);
        (, uint256 level,) = _seekMember(indexId + 1, superSafe);
        return level >= depthTreeLimit[org];
    }

    /// @dev Method to Validate is ID Squad a SuperSafe of a Squad
    /// @param squad ID's of the squad
    /// @param superSafe ID's of the Safe
    /// @return bool
    function isSuperSafe(uint256 superSafe, uint256 squad)
        public
        view
        returns (bool)
    {
        if (superSafe == 0 || squad == 0) return false;
        bytes32 org = getOrgBySquad(superSafe);
        DataTypes.Squad memory childSquad = squads[org][squad];
        // Check if the Child Squad is was removed or not Exist and Return False
        if (
            (childSquad.safe == address(0))
                || (childSquad.tier == DataTypes.Tier.REMOVED)
                || (childSquad.tier == DataTypes.Tier.ROOT)
        ) {
            return false;
        }
        return (childSquad.superSafe == superSafe);
    }

    /// @dev Method to Validate is ID Squad is Pending to Disconnect (was Removed by SuperSafe)
    /// @param squad ID's of the squad
    /// @param rootSafe ID's of Root Safe
    /// @return bool
    function isPendingRemove(uint256 rootSafe, uint256 squad)
        public
        view
        returns (bool)
    {
        DataTypes.Squad memory childSquad = squads[getOrgBySquad(squad)][squad];
        // Check if the Child Squad is was removed or not Exist and Return False
        if (
            (childSquad.safe == address(0))
                || (childSquad.tier == DataTypes.Tier.SQUAD)
                || (childSquad.tier == DataTypes.Tier.ROOT)
        ) {
            return false;
        }
        return (childSquad.superSafe == rootSafe);
    }

    function isSafeRegistered(address safe) public view returns (bool) {
        if ((safe == address(0)) || safe == Constants.SENTINEL_ADDRESS) {
            return false;
        }
        if (getOrgHashBySafe(safe) == bytes32(0)) return false;
        if (getSquadIdBySafe(getOrgHashBySafe(safe), safe) == 0) return false;
        return true;
    }

    /// @dev Method to get Root Safe of a Squad
    /// @param squadId ID's of the squad
    /// @return rootSafeId uint256 Root Safe Id's
    function getRootSafe(uint256 squadId)
        public
        view
        returns (uint256 rootSafeId)
    {
        bytes32 org = getOrgBySquad(squadId);
        DataTypes.Squad memory childSquad = squads[org][squadId];
        if (childSquad.superSafe == 0) return squadId;
        (,, rootSafeId) = _seekMember(indexId + 1, squadId);
    }

    /// @notice Get the safe address of a squad
    /// @dev Method for getting the safe address of a squad
    /// @param squad uint256 of the squad
    /// @return safe address
    function getSquadSafeAddress(uint256 squad)
        public
        view
        SquadRegistered(squad)
        returns (address)
    {
        bytes32 org = getOrgBySquad(squad);
        return squads[org][squad].safe;
    }

    /// @dev Method to get Org by Safe
    /// @param safe address of Safe
    /// @return Org Hashed Name
    function getOrgHashBySafe(address safe) public view returns (bytes32) {
        for (uint256 i = 0; i < orgHash.length; ++i) {
            if (getSquadIdBySafe(orgHash[i], safe) != 0) {
                return orgHash[i];
            }
        }
        return bytes32(0);
    }

    /// @dev Method to get Squad ID by safe address
    /// @param org bytes32 hashed name of the Organization
    /// @param safe Safe address
    /// @return Squad ID
    function getSquadIdBySafe(bytes32 org, address safe)
        public
        view
        returns (uint256)
    {
        if (!isOrgRegistered(org)) {
            revert Errors.OrgNotRegistered(org);
        }
        /// Check if the Safe address is into an Squad mapping
        for (uint256 i = 0; i < indexSquad[org].length; ++i) {
            if (squads[org][indexSquad[org][i]].safe == safe) {
                return indexSquad[org][i];
            }
        }
        return 0;
    }

    /// @notice call to get the orgHash based on squad id
    /// @dev Method to get the hashed orgHash based on squad id
    /// @param squad uint256 of the squad
    /// @return orgSquad Hash (Dao's Name)
    function getOrgBySquad(uint256 squad)
        public
        view
        returns (bytes32 orgSquad)
    {
        if ((squad == 0) || (squad > indexId)) revert Errors.InvalidSquadId();
        for (uint256 i = 0; i < orgHash.length; ++i) {
            if (squads[orgHash[i]][squad].safe != address(0)) {
                orgSquad = orgHash[i];
            }
        }
        if (orgSquad == bytes32(0)) revert Errors.SquadNotRegistered(squad);
    }

    /// @notice Check if a user is an safe lead of a squad/org
    /// @param squad address of the squad
    /// @param user address of the user that is a lead or not
    /// @return bool
    function isSafeLead(uint256 squad, address user)
        public
        view
        returns (bool)
    {
        bytes32 org = getOrgBySquad(squad);
        DataTypes.Squad memory _squad = squads[org][squad];
        if (_squad.safe == address(0)) return false;
        if (_squad.lead == user) {
            return true;
        }
        return false;
    }

    /// @notice Refactoring method for Create Org or RootSafe
    /// @dev Method Private for Create Org or RootSafe
    /// @param name String Name of the Organization
    /// @param caller Safe Caller to Create Org or RootSafe
    /// @param newRootSafe Safe Address to Create Org or RootSafe
    function _createOrgOrRoot(
        string memory name,
        address caller,
        address newRootSafe
    ) private returns (uint256 squadId) {
        if (bytes(name).length == 0) {
            revert Errors.EmptyName();
        }
        bytes32 org = caller == newRootSafe
            ? bytes32(keccak256(abi.encodePacked(name)))
            : getOrgHashBySafe(caller);
        if (isOrgRegistered(org) && caller == newRootSafe) {
            revert Errors.OrgAlreadyRegistered(org);
        }
        if (isSafeRegistered(newRootSafe)) {
            revert Errors.SafeAlreadyRegistered(newRootSafe);
        }
        squadId = indexId;
        squads[org][squadId] = DataTypes.Squad({
            tier: DataTypes.Tier.ROOT,
            name: name,
            lead: address(0),
            safe: newRootSafe,
            child: new uint256[](0),
            superSafe: 0
        });
        indexSquad[org].push(squadId);
        indexId++;

        /// Assign SUPER_SAFE Role + SAFE_ROOT Role
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        _authority.setUserRole(
            newRootSafe, uint8(DataTypes.Role.ROOT_SAFE), true
        );
        _authority.setUserRole(
            newRootSafe, uint8(DataTypes.Role.SUPER_SAFE), true
        );
    }

    /// @dev Function for refactoring DisconnectSafe Method, and RemoveWholeTree in one Method
    /// @param squad ID's of the organization
    function _exitSafe(uint256 squad) private {
        bytes32 org = getOrgBySquad(squad);
        address _squad = squads[org][squad].safe;
        address caller = _msgSender();
        IGnosisSafe gnosisTargetSafe = IGnosisSafe(_squad);
        removeIndexSquad(org, squad);
        delete squads[org][squad];

        /// Disable Guard
        bytes memory data =
            abi.encodeWithSelector(IGnosisSafe.setGuard.selector, address(0));
        /// Execute transaction from target safe
        _executeModuleTransaction(_squad, data);

        /// Disable Module
        address prevModule = getPreviewModule(caller);
        if (prevModule == address(0)) {
            revert Errors.PreviewModuleNotFound(_squad);
        }
        data = abi.encodeWithSelector(
            IGnosisSafe.disableModule.selector, prevModule, address(this)
        );
        /// Execute transaction from target safe
        _executeModuleTransaction(_squad, data);

        emit Events.SafeDisconnected(
            org, squad, address(gnosisTargetSafe), caller
        );
    }

    /// @notice disable safe lead roles
    /// @dev Associated roles: SAFE_LEAD || SAFE_LEAD_EXEC_ON_BEHALF_ONLY || SAFE_LEAD_MODIFY_OWNERS_ONLY
    /// @param user Address of the user to disable roles
    function disableSafeLeadRoles(address user) private {
        RolesAuthority _authority = RolesAuthority(rolesAuthority);
        if (_authority.doesUserHaveRole(user, uint8(DataTypes.Role.SAFE_LEAD)))
        {
            _authority.setUserRole(user, uint8(DataTypes.Role.SAFE_LEAD), false);
        } else if (
            _authority.doesUserHaveRole(
                user, uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY)
            )
        ) {
            _authority.setUserRole(
                user, uint8(DataTypes.Role.SAFE_LEAD_EXEC_ON_BEHALF_ONLY), false
            );
        } else if (
            _authority.doesUserHaveRole(
                user, uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY)
            )
        ) {
            _authority.setUserRole(
                user, uint8(DataTypes.Role.SAFE_LEAD_MODIFY_OWNERS_ONLY), false
            );
        }
    }

    /// @notice Private method to remove indexId from mapping of indexes into organizations
    /// @param org ID's of the organization
    /// @param squad uint256 of the squad
    function removeIndexSquad(bytes32 org, uint256 squad) private {
        for (uint256 i = 0; i < indexSquad[org].length; ++i) {
            if (indexSquad[org][i] == squad) {
                indexSquad[org][i] = indexSquad[org][indexSquad[org].length - 1];
                indexSquad[org].pop();
                break;
            }
        }
    }

    /// @notice Private method to remove Org from Array of Hashes of organizations
    /// @param org ID's of the organization
    function removeOrg(bytes32 org) private {
        for (uint256 i = 0; i < orgHash.length; ++i) {
            if (orgHash[i] == org) {
                orgHash[i] = orgHash[orgHash.length - 1];
                orgHash.pop();
                break;
            }
        }
    }

    /// @notice Method for refactoring the methods getRootSafe, isTreeMember, and isLimitTree, in one method
    /// @dev Method to Getting if is Member, the  Level and Root Safe
    /// @param superSafe ID's of the Super Safe squad
    /// @param childSafe ID's of the Child Safe
    function _seekMember(uint256 superSafe, uint256 childSafe)
        private
        view
        returns (bool isMember, uint256 level, uint256 rootSafeId)
    {
        bytes32 org = getOrgBySquad(childSafe);
        DataTypes.Squad memory childSquad = squads[org][childSafe];
        // Check if the Child Squad is was removed or not Exist and Return False
        if (
            (childSquad.safe == address(0))
                || (childSquad.tier == DataTypes.Tier.REMOVED)
        ) {
            return (isMember, level, rootSafeId);
        }
        // Storage the Root Safe Address in the next superSafe is Zero
        rootSafeId = childSquad.superSafe;
        uint256 currentSuperSafe = rootSafeId;
        level = 2; // Level start in 1
        while (currentSuperSafe != 0) {
            childSquad = squads[org][currentSuperSafe];
            // Validate if the Current Super Safe is Equal the SuperSafe try to Found, in case is True, storage True in isMember
            isMember =
                !isMember && currentSuperSafe == superSafe ? true : isMember;
            // Validate if the Current Super Safe of the Chield Squad is Equal Zero
            // Return the isMember, level and rootSafeId with actual value
            if (childSquad.superSafe == 0) return (isMember, level, rootSafeId);
            // else update the Vaule of possible Root Safe
            else rootSafeId = childSquad.superSafe;
            // Update the Current Super Safe with the Super Safe of the Child Squad
            currentSuperSafe = childSquad.superSafe;
            // Update the Level for the next iteration
            level++;
        }
    }

    /// @dev Method to getting the All Gorup Member for the Tree of the Root Safe/Org indicate in the args
    /// @param rootSafe Gorup ID's of the root safe
    /// @param indexSquadByOrg Array of the Squad ID's of the Org
    /// @return indexTree Array of the Squad ID's of the Tree
    function getTreeMember(uint256 rootSafe, uint256[] memory indexSquadByOrg)
        private
        view
        returns (uint256[] memory indexTree)
    {
        uint256 index;
        for (uint256 i = 0; i < indexSquadByOrg.length; ++i) {
            if (
                (getRootSafe(indexSquadByOrg[i]) == rootSafe)
                    && (indexSquadByOrg[i] != rootSafe)
            ) {
                index++;
            }
        }
        indexTree = new uint256[](index);
        index = 0;
        for (uint256 i = 0; i < indexSquadByOrg.length; ++i) {
            if (
                (getRootSafe(indexSquadByOrg[i]) == rootSafe)
                    && (indexSquadByOrg[i] != rootSafe)
            ) {
                indexTree[index] = indexSquadByOrg[i];
                index++;
            }
        }
    }
}

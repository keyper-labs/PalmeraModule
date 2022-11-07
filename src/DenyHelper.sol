// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {GnosisSafeMath} from "@safe-contracts/external/GnosisSafeMath.sol";
import {Address} from "@openzeppelin/utils/Address.sol";

abstract contract DenyHelper {
    using GnosisSafeMath for uint256;
    using Address for address;
    /// @dev Wallet Sentinel

    address internal constant SENTINEL_WALLETS = address(0x1);

    /// @dev Deny/Allowlist Flags by Org
	/// @dev Org ID ---> Flag
    mapping(address => bool) public allowFeature;
    mapping(address => bool) public denyFeature;

    /// @dev Counters by Org
	/// @dev Org ID ---> Counter
    mapping(address => uint256) public allowedCount;
    mapping(address => uint256) public deniedCount;

    /// @dev Mapping of Orgs to Wallets Deny or Allowed
	/// @dev Org ID ---> Mapping of Orgs to Wallets Deny or Allowed
    mapping (address => mapping(address => address)) internal allowed;
    mapping (address => mapping(address => address)) internal denied;

    /// @dev Events
    event AddedToTheAllowedList(address[] users);
    event AddedToTheDeniedList(address[] users);
    event DroppedFromAllowedList(address indexed user);
    event DroppedFromDeniedList(address indexed user);

    /// @dev Errors
    error ZeroAddressProvided();
    error InvalidAddressProvided();
    error UserAlreadyOnAllowedList();
    error UserAlreadyOnDeniedList();
    error AddresNotAllowed();
    error AddressDenied();

    /// @dev Modifier for Valid if wallet is Zero Address or Not
    modifier validAddress(address to) {
        if (to == address(0) || to == SENTINEL_WALLETS) {
            revert InvalidAddressProvided();
        }
        _;
    }

    /// @dev Modifier for Valid if wallet is Denied or Not
    modifier Denied(address org,address _user) {
        if (allowFeature[org]) {
            if (isAllowed(org, _user)) revert AddresNotAllowed();
            _;
        } else if (denyFeature[org]) {
            if (isDenied(org, _user)) revert AddressDenied();
            _;
        } else {
            _;
        }
    }

    /// @dev Funtion to Add Wallet to allowedList based on Approach of Safe Contract - Owner Manager
	/// @param org Address of Org where the Wallet to be added to the allowedList
    /// @param users Array of Address of the Wallet to be added to allowedList
    function addToAllowedList(address org, address[] memory users) external virtual {
        if (users.length == 0) revert ZeroAddressProvided();
        address currentWallet = SENTINEL_WALLETS;
        for (uint256 i = 0; i < users.length; i++) {
            address wallet = users[i];
            if (
                wallet == address(0) || wallet == SENTINEL_WALLETS
                    || wallet == address(this) || currentWallet == wallet
            ) revert InvalidAddressProvided();
            // Avoid duplicate wallet
            if (allowed[org][wallet] != address(0)) {
                revert UserAlreadyOnAllowedList();
            }
            // Add wallet to allowedList
            allowed[org][currentWallet] = wallet;
            currentWallet = wallet;
        }
        allowed[org][currentWallet] = SENTINEL_WALLETS;
        allowedCount[org] += users.length;
        emit AddedToTheAllowedList(users);
    }

    /// @dev Funtion to Add Wallet to denyList based on Approach of Safe Contract - Owner Manager
	/// @param org Address of Org where the Wallet to be added to the denyList
    /// @param users Array of Address of the Wallet to be added to denyList
    function addToDeniedList(address org, address[] memory users) external virtual {
        if (users.length == 0) revert ZeroAddressProvided();
        address currentWallet = SENTINEL_WALLETS;
        for (uint256 i = 0; i < users.length; i++) {
            address wallet = users[i];
            if (
                wallet == address(0) || wallet == SENTINEL_WALLETS
                    || wallet == address(this) || currentWallet == wallet
            ) revert InvalidAddressProvided();
            // Avoid duplicate wallet
            if (denied[org][wallet] != address(0)) {
                revert UserAlreadyOnDeniedList();
            }
            // Add wallet to deniedList
            denied[org][currentWallet] = wallet;
            currentWallet = wallet;
        }
        denied[org][currentWallet] = SENTINEL_WALLETS;
        deniedCount[org] += users.length;
        emit AddedToTheDeniedList(users);
    }

    function dropFromAllowedList(address org, address user) external virtual validAddress(user) {
        address prevUser = getPrevUser(org, user, true);
        allowed[org][prevUser] = allowed[org][user];
        allowed[org][user] = address(0);
        allowedCount[org] = allowedCount[org] > 1 ? allowedCount[org].sub(1) : 0;
        emit DroppedFromAllowedList(user);
    }

    /// @dev Function to Drop Wallet from Denied based on Approach of Safe Contract - Owner Manager
    /// @param user Array of Address of the Wallet to be dropped to DeniedList
    function dropFromDeniedList(address org, address user) external virtual validAddress(user) {
        address prevUser = getPrevUser(org, user, false);
        denied[org][prevUser] = denied[org][user];
        denied[org][user] = address(0);
        deniedCount[org] = deniedCount[org] > 1 ? deniedCount[org].sub(1) : 0;
        emit DroppedFromDeniedList(user);
    }

    /// @dev Method to Enable Allowlist
    function enableAllowlist(address org) external virtual {
        allowFeature[org] = true;
        denyFeature[org] = false;
    }

    /// @dev Method to Enable Allowlist
    function enableDenylist(address org) external virtual {
        denyFeature[org] = true;
        allowFeature[org] = false;
    }

    function isAllowed(address org, address wallet) public view returns (bool) {
        return wallet != SENTINEL_WALLETS && allowed[org][wallet] != address(0)
            && wallet != address(0);
    }

    function isDenied(address org, address wallet) public view returns (bool) {
        return wallet != SENTINEL_WALLETS && denied[org][wallet] != address(0)
            && wallet != address(0);
    }

    function getAll(address org) public view returns (address[] memory result) {
		bool Allowed = allowFeature[org];
		uint256 count = Allowed ? allowedCount[org] : deniedCount[org];
        result = new address[](count);
        address currentWallet = Allowed ? allowed[org][SENTINEL_WALLETS] : denied[org][SENTINEL_WALLETS];
        uint256 i = 0;
        while (currentWallet != SENTINEL_WALLETS) {
            result[i] = currentWallet;
            currentWallet = Allowed ? allowed[org][currentWallet] : denied[org][currentWallet];
            i++;
        }
        return result;
    }

    /// @dev Function to get the Previous User of the Wallet
    /// @param user Address of the Wallet
    function getPrevUser(address org, address user, bool Allowed)
        public
        /// originally internal
        view
        returns (address prevUser)
    {
        prevUser = SENTINEL_WALLETS;
        address currentWallet = Allowed ? allowed[org][prevUser] : denied[org][prevUser];
        while (currentWallet != SENTINEL_WALLETS) {
            if (currentWallet == user) {
                return prevUser;
            }
            prevUser = currentWallet;
            currentWallet = Allowed ? allowed[org][currentWallet] : denied[org][currentWallet];
        }
        return prevUser;
    }
}

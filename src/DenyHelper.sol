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
    mapping(address => uint256) public listCount;

    /// @dev Mapping of Orgs to Wallets Deny or Allowed
    /// @dev Org ID ---> Mapping of Orgs to Wallets Deny or Allowed
    mapping(address => mapping(address => address)) internal listed;

    /// @dev Events
    event AddedToList(address[] users);
    event DroppedFromList(address indexed user);

    /// @dev Errors
    error ZeroAddressProvided();
    error InvalidAddressProvided();
    error UserAlreadyOnList();
    error AddresNotAllowed();
    error AddressDenied();
    error DenyHelpersDisabled();
    error ListEmpty();

    /// @dev Modifier for Valid if wallet is Zero Address or Not
    modifier validAddress(address to) {
        if (to == address(0) || to == SENTINEL_WALLETS) {
            revert InvalidAddressProvided();
        }
        _;
    }

    /// @dev Modifier for Valid if wallet is Denied or Not
    modifier Denied(address org, address _user) {
        if (allowFeature[org]) {
            if (!isListed(org, _user)) revert AddresNotAllowed();
            _;
        } else if (denyFeature[org]) {
            if (isListed(org, _user)) revert AddressDenied();
            _;
        } else {
            _;
        }
    }

    /// @dev Funtion to Add Wallet to the List based on Approach of Safe Contract - Owner Manager
    /// @param org Address of Org where the Wallet to be added to the List
    /// @param users Array of Address of the Wallet to be added to the List
    function addToList(address org, address[] memory users) external virtual {
        if (users.length == 0) revert ZeroAddressProvided();
        if (!allowFeature[org] && !denyFeature[org]) {
            revert DenyHelpersDisabled();
        }
        address currentWallet = SENTINEL_WALLETS;
        for (uint256 i = 0; i < users.length; i++) {
            address wallet = users[i];
            if (
                wallet == address(0) || wallet == SENTINEL_WALLETS
                    || wallet == address(this) || currentWallet == wallet
            ) revert InvalidAddressProvided();
            // Avoid duplicate wallet
            if (listed[org][wallet] != address(0)) {
                revert UserAlreadyOnList();
            }
            // Add wallet to List
            listed[org][currentWallet] = wallet;
            currentWallet = wallet;
        }
        listed[org][currentWallet] = SENTINEL_WALLETS;
        listCount[org] += users.length;
        emit AddedToList(users);
    }

    /// @dev Function to Drop Wallet from the List  based on Approach of Safe Contract - Owner Manager
    /// @param org Address of Org where the Wallet to be dropped of the List
    /// @param user Array of Address of the Wallet to be dropped of the List
    function dropFromList(address org, address user) external virtual {
        if (!allowFeature[org] && !denyFeature[org]) {
            revert DenyHelpersDisabled();
        }
        if (listCount[org] == 0) revert ListEmpty();
        if (!isListed(org, user)) revert InvalidAddressProvided();
        address prevUser = getPrevUser(org, user);
        listed[org][prevUser] = listed[org][user];
        listed[org][user] = address(0);
        listCount[org] = listCount[org] > 1 ? listCount[org].sub(1) : 0;
        emit DroppedFromList(user);
    }

    /// @dev Method to Enable Allowlist
    function enableAllowlist(address org) external virtual {
        allowFeature[org] = true;
        denyFeature[org] = false;
    }

    /// @dev Method to Enable Allowlist
    function enableDenylist(address org) external virtual {
        allowFeature[org] = false;
        denyFeature[org] = true;
    }

    /// @dev Method to Disable All
    function disableDenyHelper(address org) external virtual {
        allowFeature[org] = false;
        denyFeature[org] = false;
    }

    function isListed(address org, address wallet) public view returns (bool) {
        return wallet != SENTINEL_WALLETS && listed[org][wallet] != address(0)
            && wallet != address(0);
    }

    function getAll(address org)
        public
        view
        returns (address[] memory result)
    {
        uint256 count = listCount[org];
        if (count == 0) {
            return new address[](0);
        }
        result = new address[](count);
        address currentWallet = listed[org][SENTINEL_WALLETS];
        uint256 i = 0;
        while (currentWallet != SENTINEL_WALLETS) {
            result[i] = currentWallet;
            currentWallet = listed[org][currentWallet];
            i++;
        }
        return result;
    }

    /// @dev Function to get the Previous User of the Wallet
    /// @param user Address of the Wallet
    function getPrevUser(address org, address user)
        public
        view
        returns (
            /// originally internal
            address prevUser
        )
    {
        prevUser = SENTINEL_WALLETS;
        address currentWallet = listed[org][prevUser];
        while (
            (currentWallet != SENTINEL_WALLETS) && (currentWallet != address(0))
                && (listCount[org] > 0)
        ) {
            if (currentWallet == user) {
                return prevUser;
            }
            prevUser = currentWallet;
            currentWallet = listed[org][currentWallet];
        }
        return prevUser;
    }
}

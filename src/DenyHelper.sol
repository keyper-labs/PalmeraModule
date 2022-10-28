// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {Address} from "@openzeppelin/utils/Address.sol";

abstract contract DenyHelper {
    using Address for address;
    /// @dev Wallet Sentinel

    address internal constant SENTINEL_WALLETS = address(0x1);

    /// @dev Counters
    uint256 public allowedCount;
    uint256 public deniedCount;

    /// @dev Listed info
    mapping(address => address) internal allowed;
    mapping(address => address) internal denied;

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

    /// @dev Modifier for Valid if wallet is Zero Address or Not
    modifier validAddress(address to) {
        if (to == address(0) || to == SENTINEL_WALLETS) {
            revert("Invalid address (Address Zero)");
        }
        _;
    }

    /// @dev Modifier for Valid if wallet is Allowed or Not
    modifier Allowed(address _user) {
        if (!isAllowed(_user)) revert("Address is not allowed");
        _;
    }

    /// @dev Modifier for Valid if wallet is Denied or Not
    modifier Denied(address _user) {
        if (isDenied(_user)) revert("Address is denied");
        _;
    }

    /// @dev Funtion to Add Wallet to allowedList based on Approach of Safe Contract - Owner Manager
    /// @param users Array of Address of the Wallet to be added to allowedList
    function addToAllowedList(address[] memory users) public {
        if (users.length == 0) revert ZeroAddressProvided();
        address currentWallet = SENTINEL_WALLETS;
        for (uint256 i = 0; i < users.length; i++) {
            address wallet = users[i];
            if (
                wallet == address(0) || wallet == SENTINEL_WALLETS
                    || wallet == address(this) || currentWallet == wallet
            ) revert InvalidAddressProvided();
            // Avoid duplicate wallet
            if (allowed[wallet] != address(0)) {
                revert UserAlreadyOnAllowedList();
            }
            // Add wallet to allowedList
            allowed[currentWallet] = wallet;
            currentWallet = wallet;
        }
        allowed[currentWallet] = SENTINEL_WALLETS;
        allowedCount += users.length;
        emit AddedToTheAllowedList(users);
    }

    function addToDeniedList(address[] memory users) public {
        if (users.length == 0) revert ZeroAddressProvided();
        address currentWallet = SENTINEL_WALLETS;
        for (uint256 i = 0; i < users.length; i++) {
            address wallet = users[i];
            if (
                wallet == address(0) || wallet == SENTINEL_WALLETS
                    || wallet == address(this) || currentWallet == wallet
            ) revert InvalidAddressProvided();
            // Avoid duplicate wallet
            if (denied[wallet] != address(0)) {
                revert UserAlreadyOnDeniedList();
            }
            // Add wallet to deniedList
            denied[currentWallet] = wallet;
            currentWallet = wallet;
        }
        denied[currentWallet] = SENTINEL_WALLETS;
        deniedCount += users.length;
        emit AddedToTheDeniedList(users);
    }

    function dropFromAllowedList(address user) external validAddress(user) {
        address prevUser = getPrevUser(user);
        allowed[prevUser] = allowed[user];
        allowed[user] = address(0);
        allowedCount--;
        emit DroppedFromAllowedList(user);
    }

    /// @dev Function to Drop Wallet from Denied based on Approach of Safe Contract - Owner Manager
    /// @param user Array of Address of the Wallet to be dropped to DeniedList
    function dropFromDeniedList(address user) external validAddress(user) {
        address prevUser = getPrevUser(user);
        denied[prevUser] = denied[user];
        denied[user] = address(0);
        deniedCount--;
        emit DroppedFromDeniedList(user);
    }

    function isAllowed(address wallet) public view returns (bool) {
        return wallet != SENTINEL_WALLETS && allowed[wallet] != address(0)
            && wallet != address(0);
    }

    function isDenied(address wallet) public view returns (bool) {
        return wallet != SENTINEL_WALLETS && denied[wallet] != address(0)
            && wallet != address(0);
    }

    function getAllAllowed() public view returns (address[] memory result) {
        result = new address[](allowedCount);
        address currentWallet = allowed[SENTINEL_WALLETS];
        uint256 i = 0;
        while (currentWallet != SENTINEL_WALLETS) {
            result[i] = currentWallet;
            currentWallet = allowed[currentWallet];
            i++;
        }
        return result;
    }

    function getAllDenied() public view returns (address[] memory result) {
        result = new address[](deniedCount);
        address currentWallet = denied[SENTINEL_WALLETS];
        uint256 i = 0;
        while (currentWallet != SENTINEL_WALLETS) {
            result[i] = currentWallet;
            currentWallet = denied[currentWallet];
            i++;
        }
        return result;
    }

    /// @dev Function to get the Previous User of the Wallet
    /// @param user Address of the Wallet
    function getPrevUser(address user)
        public
        view
        returns (address prevUser)
    {
        prevUser = SENTINEL_WALLETS;
        address currentWallet = allowed[prevUser];
        while (currentWallet != SENTINEL_WALLETS) {
            if (currentWallet == user) {
                return prevUser;
            }
            prevUser = currentWallet;
            currentWallet = allowed[currentWallet];
        }
        return prevUser;
    }
}

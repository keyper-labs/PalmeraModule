// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {GnosisSafeMath} from "@safe-contracts/external/GnosisSafeMath.sol";
import {Address} from "@openzeppelin/utils/Address.sol";
import {Context} from "@openzeppelin/utils/Context.sol";
import {Errors} from "../libraries/Errors.sol";
import {Constants} from "../libraries/Constants.sol";
import {Events} from "../libraries/Events.sol";

/// @title DenyHelper
/// @custom:security-contact general@palmeradao.xyz
abstract contract DenyHelper is Context {
    using GnosisSafeMath for uint256;
    using Address for address;

    /// @dev Deny/Allowlist Flags by Org
    /// @dev Org ID ---> Flag
    mapping(bytes32 => bool) public allowFeature;
    mapping(bytes32 => bool) public denyFeature;

    /// @dev Counters by Org
    /// @dev Org ID ---> Counter
    mapping(bytes32 => uint256) public listCount;

    /// @dev Mapping of Orgs to Wallets Deny or Allowed
    /// @dev Org ID ---> Mapping of Orgs to Wallets Deny or Allowed
    mapping(bytes32 => mapping(address => address)) internal listed;

    /// @dev Modifier for Valid if wallet is Zero Address or Not
    /// @param to Address to check
    modifier validAddress(address to) {
        if (to == address(0) || to == Constants.SENTINEL_ADDRESS) {
            revert Errors.InvalidAddressProvided();
        }
        _;
    }

    /// @dev Modifier for Valid if wallet is Denied/Allowed or Not
    /// @param org Hash (Dao's name) of the Org
    /// @param wallet Address to check if Denied/Allowed
    modifier Denied(bytes32 org, address wallet) {
        if (wallet == address(0) || wallet == Constants.SENTINEL_ADDRESS) {
            revert Errors.InvalidAddressProvided();
        } else if (allowFeature[org]) {
            if (!isListed(org, wallet)) revert Errors.AddresNotAllowed();
            _;
        } else if (denyFeature[org]) {
            if (isListed(org, wallet)) revert Errors.AddressDenied();
            _;
        } else {
            _;
        }
    }

    /// @dev Function to check if a wallet is Denied/Allowed
    /// @param org Hash (Dao's name) of the Org
    /// @param wallet Address to check the wallet is Listed
    /// @return True if the wallet is Listed
    function isListed(bytes32 org, address wallet) public view returns (bool) {
        return wallet != Constants.SENTINEL_ADDRESS
            && listed[org][wallet] != address(0) && wallet != address(0);
    }

    /// @dev Method to get All Wallet of the List
    /// @param org Hash (Dao's name) of the Org
    /// @return result returns Array of Wallets
    function getAll(bytes32 org)
        public
        view
        returns (address[] memory result)
    {
        uint256 count = listCount[org];
        if (count == 0) {
            return new address[](0);
        }
        result = new address[](count);
        address currentWallet = listed[org][Constants.SENTINEL_ADDRESS];
        uint256 i = 0;
        while (currentWallet != Constants.SENTINEL_ADDRESS) {
            result[i] = currentWallet;
            currentWallet = listed[org][currentWallet];
            i++;
        }
        return result;
    }

    /// @dev Function to get the Previous User of the Wallet
    /// @param org Address of Org where get the Previous User of the Wallet
    /// @param wallet Address of the Wallet
    /// @return prevUser Address of the Previous User of the Wallet
    function getPrevUser(bytes32 org, address wallet)
        public
        view
        returns (address prevUser)
    {
        prevUser = Constants.SENTINEL_ADDRESS;
        address currentWallet = listed[org][prevUser];
        while (
            (currentWallet != Constants.SENTINEL_ADDRESS)
                && (currentWallet != address(0)) && (listCount[org] > 0)
        ) {
            if (currentWallet == wallet) {
                return prevUser;
            }
            prevUser = currentWallet;
            currentWallet = listed[org][currentWallet];
        }
        return prevUser;
    }
}

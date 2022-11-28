// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {GnosisSafeMath} from "@safe-contracts/external/GnosisSafeMath.sol";
import {Address} from "@openzeppelin/utils/Address.sol";
import {Context} from "@openzeppelin/utils/Context.sol";
import {Errors} from "../libraries/Errors.sol";
import {Constants} from "../libraries/Constants.sol";
import {Events} from "../libraries/Events.sol";

abstract contract DenyHelperV2 is Context {
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
    modifier validAddress(address to) {
        if (to == address(0) || to == Constants.SENTINEL_ADDRESS) {
            revert Errors.InvalidAddressProvided();
        }
        _;
    }

    /// @dev Modifier for Valid if wallet is Denied/Allowed or Not
    modifier Denied(bytes32 org, address _user) {
        if (_user == address(0) || _user == Constants.SENTINEL_ADDRESS) {
            revert Errors.InvalidAddressProvided();
        } else if (allowFeature[org]) {
            if (!isListed(org, _user)) revert Errors.AddresNotAllowed();
            _;
        } else if (denyFeature[org]) {
            if (isListed(org, _user)) revert Errors.AddressDenied();
            _;
        } else {
            _;
        }
    }

    function isListed(bytes32 org, address wallet) public view returns (bool) {
        return wallet != Constants.SENTINEL_ADDRESS
            && listed[org][wallet] != address(0) && wallet != address(0);
    }

    /// @dev Method to get All Wallet of the List
    /// @param org Address of Org where to get the List of All Wallet
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

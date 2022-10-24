// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import {KeyperModule} from "src/KeyperModule.sol";
import {console} from "forge-std/console.sol";

contract BlacklistHelper {

    /// @dev Definition of the Blacklist Helper Contract
    string public constant NAME = "Blacklist Helper";
    string public constant VERSION = "0.1.0";

    // Listed info
    mapping(address => bool) internal whitelisted;
    mapping(address => bool) internal blacklisted;

    // KeyperModule instance
    KeyperModule public keyperModule;

    // Events
    event AddedToWhitelist(address indexed user);
    event AddedToBlacklist(address indexed user);

    // Errors
    error userAlreadyOnWhitelist();
    error userAlreadyOnBlacklist();

    modifier validAddress(address _to) {
        require(_to != address(0), "Invalid address (Address Zero)");
        _;
    }

    constructor(address _keyperModule) {
        keyperModule = KeyperModule(_keyperModule);
    }

    function addToWhiteList(address _user) public validAddress(_user) {

        if (whitelisted[_user] == true) revert userAlreadyOnWhitelist();

        whitelisted[_user] = true;

        emit AddedToWhitelist(_user);
    }

    function addToBlacklist(address _user) public validAddress(_user) {

        if (blacklisted[_user] == true) revert userAlreadyOnBlacklist();

        blacklisted[_user] = true;

        emit AddedToBlacklist(_user);
    }
}
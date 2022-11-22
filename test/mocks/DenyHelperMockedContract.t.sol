// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DenyHelper} from "../../src/DenyHelper.sol";

contract DenyHelperMockedContract is DenyHelper {
    address private mockAddress = address(0x321);
}

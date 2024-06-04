// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import {DenyHelper} from "../../src/DenyHelper.sol";

/// @title DenyHelperMockedContract
/// @custom:security-contact general@palmeradao.xyz
contract DenyHelperMockedContract is DenyHelper {
    address private mockAddress = address(0x321);
}

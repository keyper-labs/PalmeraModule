// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "./helpers/DeployHelper.t.sol";

contract PalmeraRolesTestFallbackAndReceive is DeployHelper {
    /// @notice Set up the environment for testing
    function setUp() public {
        deployAllContracts(60);
    }

    /// @notice Calling a non-existent function

    function testFallbackFunctionNonExistentFunction() public {
        (bool success,) = address(palmeraRolesContract).call(
            abi.encodeWithSignature("nonExistentFunction()")
        );
        assertFalse(
            success,
            "Fallback function should revert on non-existent function call"
        );
    }

    /// @notice Sending ETH without data
    function testReceiveFunctionSendETHWithoutData() public {
        vm.deal(address(this), 1 ether); // Give this contract 1 ether to work with
        (bool success,) = address(palmeraRolesContract).call{value: 1 ether}("");
        assertFalse(
            success, "Receive function should revert on ETH send without data"
        );
    }

    /// @notice Sending ETH with data that does not match any function
    function testFallbackFunctionSendETHWithInvalidData() public {
        vm.deal(address(this), 1 ether); // Give this contract 1 ether to work with
        (bool success,) = address(palmeraRolesContract).call{value: 1 ether}(
            abi.encodeWithSignature("setUserRole()")
        );
        assertFalse(
            success,
            "Fallback function should revert on ETH send with invalid data"
        );
    }
}

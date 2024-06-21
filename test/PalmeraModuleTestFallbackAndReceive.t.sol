// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

import "./helpers/DeployHelper.t.sol";

contract PalmeraModuleTestFallbackAndReceive is DeployHelper {
    /// @notice Set up the environment for testing
    function setUp() public {
        deployAllContracts(60);
    }

    /// @notice Calling a non-existent function
    function testFallbackFunctionNonExistentFunction() public {
        (bool success,) = address(palmeraModule).call(
            abi.encodeWithSignature("nonExistentFunction()")
        );
        assertFalse(
            success,
            "Fallback function should revert on non-existent function call"
        );
    }

    /// @notice Sending ETH without data
    function testReceiveFunctionSendETHWithoutData(uint256 iterations) public {
        iterations = (iterations % 1000) * 1 gwei;
        vm.deal(address(this), iterations); // Give this contract x gwei to work with
        (bool success,) = address(palmeraModule).call{value: iterations}("");
        assertFalse(
            success, "Receive function should revert on ETH send without data"
        );
    }

    /// @notice Sending ETH with data that does not match any function
    function testFallbackFunctionSendETHWithInvalidData(uint256 iterations)
        public
    {
        iterations = (iterations % 1000) * 1 gwei;
        vm.deal(address(this), iterations); // Give this contract x gwei to work with
        (bool success,) = address(palmeraModule).call{value: iterations}(
            abi.encodeWithSignature("execTransactionOnBehalf()")
        );
        assertFalse(
            success,
            "Fallback function should revert on ETH send with invalid data"
        );
    }
}

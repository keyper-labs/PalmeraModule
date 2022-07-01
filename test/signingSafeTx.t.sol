// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {SigningUtils} from "../src/SigningUtils.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {GnosisSafe} from "@safe-contracts/GnosisSafe.sol";

contract TestSigningSafeTx is Test, SigningUtils {
    Transaction mockTx;
    GnosisSafe safe;

    function setUp() public {
        mockTx = Transaction(
            address(0x1),
            0 gwei,
            "0x",
            Enum.Operation(1),
            5 gwei,
            5 gwei,
            5 gwei,
            address(0),
            address(0),
            "0x"
        );

        safe = new GnosisSafe();
    }

    function test2Signatures() public returns (bytes memory) {
        bytes32 domainSeparatorGnosis = safe.domainSeparator();
        bytes32 digest = createDigestExecTx(
            domainSeparatorGnosis,
            mockTx
        );

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = 0xA11CE;
        privateKeys[1] = 0xB11CD;
        bytes memory signatures = signDigestTx(privateKeys, digest);

        // This test is supposed to failed as the safe has not owners
        safe.checkSignatures(digest, mockTx.data, signatures);

        return signatures;
    }

    function signDigestTx(uint256[] memory privateKeys, bytes32 digest)
        public
        returns (bytes memory)
    {
        bytes memory signatures;
        for (uint256 i = 0; i < privateKeys.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[i], digest);
            signatures = abi.encodePacked(signatures, r, s, v);
        }

        return signatures;
    }
}

// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

/// @title SignDigestHelper
/// @custom:security-contact general@palmeradao.xyz
abstract contract SignDigestHelper is Test {
    function signDigestTx(uint256[] memory _privateKeyOwners, bytes32 digest)
        public
        pure
        returns (bytes memory)
    {
        bytes memory signatures;
        for (uint256 i; i < _privateKeyOwners.length; ++i) {
            (uint8 v, bytes32 r, bytes32 s) =
                vm.sign(_privateKeyOwners[i], digest);
            signatures = abi.encodePacked(signatures, r, s, v);
        }

        return signatures;
    }

    function sortAddresses(address[] memory addresses)
        public
        pure
        returns (address[] memory)
    {
        for (uint256 i = addresses.length - 1; i > 0; i--) {
            for (uint256 j; j < i; ++j) {
                if (addresses[i] < addresses[j]) {
                    (addresses[i], addresses[j]) = (addresses[j], addresses[i]);
                }
            }
        }

        return addresses;
    }
}

// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

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
        for (uint256 i; i < _privateKeyOwners.length;) {
            (uint8 v, bytes32 r, bytes32 s) =
                vm.sign(_privateKeyOwners[i], digest);
            signatures = abi.encodePacked(signatures, r, s, v);
            unchecked {
                ++i;
            }
        }

        return signatures;
    }

    function sortAddresses(address[] memory addresses)
        public
        pure
        returns (address[] memory)
    {
        for (uint256 i = addresses.length - 1; i > 0;) {
            for (uint256 j; j < i;) {
                if (addresses[i] < addresses[j]) {
                    (addresses[i], addresses[j]) = (addresses[j], addresses[i]);
                }
                unchecked {
                    ++j;
                }
            }
            unchecked {
                --i;
            }
        }

        return addresses;
    }
}

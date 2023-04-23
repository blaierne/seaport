// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract EquivTest 
{

    /// @dev The EIP-712 digest offsets.
    uint256 internal constant EIP712_DomainSeparator_offset = 0x02;
    uint256 internal constant EIP712_SignedOrderHash_offset = 0x22;
    uint256 internal constant EIP712_DigestPayload_size = 0x42;
    uint256 internal constant EIP_712_PREFIX = (
        0x1901000000000000000000000000000000000000000000000000000000000000
    );

    function deriveEIP712Digest_Sol(
        bytes32 domainSeparator,
        bytes32 signedOrderHash
    ) external pure returns (bytes32 digest) {
        digest = keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    domainSeparator,
                    signedOrderHash)
        );
    }

    function deriveEIP712Digest_Asm(
        bytes32 domainSeparator,
        bytes32 signedOrderHash
    ) external pure returns (bytes32 digest) {
        // Leverage scratch space to perform an efficient hash.
        assembly {
            // Place the EIP-712 prefix at the start of scratch space.
            mstore(0, EIP_712_PREFIX)

            // Place the domain separator in the next region of scratch space.
            mstore(EIP712_DomainSeparator_offset, domainSeparator)

            // Place the signed order hash in scratch space, spilling into the
            // first two bytes of the free memory pointer — this should never be
            // set as memory cannot be expanded to that size, and will be
            // zeroed out after the hash is performed.
            mstore(EIP712_SignedOrderHash_offset, signedOrderHash)

            // Hash the relevant region
            digest := keccak256(0, EIP712_DigestPayload_size)

            // Clear out the dirtied bits in the memory pointer.
            mstore(EIP712_SignedOrderHash_offset, 0)
        }
    }

}
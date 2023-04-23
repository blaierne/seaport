// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract KotlinTest {

    function name() external pure returns (bytes32) {
        // Return the name of the contract.
        assembly {
            mstore(0x40, 0x07536561706f7274)
            return(0x40, 0x20)
        }
    }

}
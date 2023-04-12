// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { FuzzExecutor } from "./FuzzExecutor.sol";
import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { AdvancedOrder } from "seaport-sol/SeaportStructs.sol";

import { OrderType } from "seaport-sol/SeaportEnums.sol";

import { AdvancedOrderLib } from "seaport-sol/SeaportSol.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { Vm } from "forge-std/Vm.sol";

contract MutationFilters {
    using AdvancedOrderLib for AdvancedOrder;

    // Determine if an order is unavailable, has been validated, has an offerer
    // with code, has an offerer equal to the caller, or is a contract order.
    function ineligibleForInvalidSignature(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (!context.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        if (order.parameters.orderType == OrderType.CONTRACT) {
            return true;
        }

        if (order.parameters.offerer == context.caller) {
            return true;
        }

        if (order.parameters.offerer.code.length != 0) {
            return true;
        }

        (bool isValidated, , , ) = context.seaport.getOrderStatus(
            context.orderHashes[orderIndex]
        );

        if (isValidated) {
            return true;
        }

        return false;
    }

    function ineligibleForOverfill(
        AdvancedOrder memory,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        if (!context.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        // TODO: think about actual criteria.
        return false;
    }

    function ineligibleForNoContractTokenAddress(
        AdvancedOrder memory,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        if (!context.expectedAvailableOrders[orderIndex]) {
            return true;
        }
        return false;
    }
}

contract FuzzMutations is Test, FuzzExecutor, MutationFilters {
    using OrderEligibilityLib for FuzzTestContext;

    function mutation_invalidSignature(
        FuzzTestContext memory context
    ) external {
        context.setIneligibleOrders(ineligibleForInvalidSignature);

        AdvancedOrder memory order = context.selectEligibleOrder();

        // TODO: fuzz on size of invalid signature
        order.signature = "";

        exec(context);
    }

    function mutation_badFractionOverfill(
        FuzzTestContext memory context
    ) external {
        context.setIneligibleOrders(ineligibleForOverfill);

        AdvancedOrder memory order = context.selectEligibleOrder();

        // TODO: fuzz on size incorrect fractions
        order.numerator = 3;
        order.denominator = 0;

        exec(context);
    }

    function mutation_noContractInvalidAddress(
        FuzzTestContext memory context
    ) external {
        context.setIneligibleOrders(ineligibleForNoContractTokenAddress);

        AdvancedOrder memory order = context.selectEligibleOrder();

        order.parameters.consideration[0].token = makeAddr("EOA");
    }
}

library OrderEligibilityLib {
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    using LibPRNG for LibPRNG.PRNG;

    function setIneligibleOrders(
        FuzzTestContext memory context,
        function(AdvancedOrder memory, uint256, FuzzTestContext memory)
            internal
            view
            returns (bool) condition
    ) internal view {
        for (uint256 i; i < context.orders.length; i++) {
            if (condition(context.orders[i], i, context)) {
                setIneligibleOrder(context, i);
            }
        }
    }

    function setIneligibleOrder(
        FuzzTestContext memory context,
        uint256 ineligibleOrderIndex
    ) internal pure {
        // Set the respective boolean for the ineligible order.
        context.ineligibleOrders[ineligibleOrderIndex] = true;
    }

    function getEligibleOrders(
        FuzzTestContext memory context
    ) internal pure returns (AdvancedOrder[] memory eligibleOrders) {
        eligibleOrders = new AdvancedOrder[](context.orders.length);

        uint256 totalEligibleOrders = 0;
        for (uint256 i = 0; i < context.ineligibleOrders.length; ++i) {
            // If the boolean is not set, the order is still eligible.
            if (!context.ineligibleOrders[i]) {
                eligibleOrders[totalEligibleOrders++] = context.orders[i];
            }
        }

        // Update the eligibleOrders array with the actual length.
        assembly {
            mstore(eligibleOrders, totalEligibleOrders)
        }
    }

    // TODO: may also want to return the order index for backing out to e.g.
    // orderIndex in fulfillments or criteria resolvers
    function selectEligibleOrder(
        FuzzTestContext memory context
    ) internal pure returns (AdvancedOrder memory eligibleOrder) {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG(context.fuzzParams.seed ^ 0xff);

        AdvancedOrder[] memory eligibleOrders = getEligibleOrders(context);

        if (eligibleOrders.length == 0) {
            revert("OrderEligibilityLib: no eligible order found");
        }

        return eligibleOrders[prng.next() % eligibleOrders.length];
    }
}

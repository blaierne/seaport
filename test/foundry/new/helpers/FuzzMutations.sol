// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console.sol";

import { Test } from "forge-std/Test.sol";
import { FuzzExecutor } from "./FuzzExecutor.sol";
import { FuzzTestContext } from "./FuzzTestContextLib.sol";
import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { OrderEligibilityLib } from "./FuzzMutationHelpers.sol";

import {
    AdvancedOrder,
    OrderParameters,
    OrderComponents
} from "seaport-sol/SeaportStructs.sol";
import {
    AdvancedOrderLib,
    OrderParametersLib
} from "seaport-sol/SeaportSol.sol";

import { ItemType, OrderType } from "seaport-sol/SeaportEnums.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { FuzzInscribers } from "./FuzzInscribers.sol";
import { dumpExecutions } from "./DebugUtil.sol";

library MutationFilters {
    using FuzzEngineLib for FuzzTestContext;
    using AdvancedOrderLib for AdvancedOrder;

    function ineligibleForEOASignature(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        if (order.parameters.orderType == OrderType.CONTRACT) {
            return true;
        }

        if (order.parameters.offerer == context.executionState.caller) {
            return true;
        }

        if (order.parameters.offerer.code.length != 0) {
            return true;
        }

        (bool isValidated, , , ) = context.seaport.getOrderStatus(
            context.executionState.orderHashes[orderIndex]
        );

        if (isValidated) {
            return true;
        }

        return false;
    }

    // Determine if an order is unavailable, has been validated, has an offerer
    // with code, has an offerer equal to the caller, or is a contract order.
    function ineligibleForInvalidSignature(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForEOASignature(order, orderIndex, context)) {
            return true;
        }

        if (order.signature.length != 64 && order.signature.length != 65) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidSigner(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForEOASignature(order, orderIndex, context)) {
            return true;
        }

        bool validLength = order.signature.length < 837 &&
            order.signature.length > 63 &&
            ((order.signature.length - 35) % 32) < 2;
        if (!validLength) {
            return true;
        }

        return false;
    }

    function ineligibleForBadSignatureV(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForEOASignature(order, orderIndex, context)) {
            return true;
        }

        if (order.signature.length != 65) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidTime(
        AdvancedOrder memory /* order */,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            return true;
        }

        return false;
    }

    function ineligibleForBadFraction(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillOrder.selector ||
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector ||
            action == context.seaport.matchOrders.selector
        ) {
            return true;
        }

        // TODO: In cases where an order is skipped since it's fully filled,
        // cancelled, or generation failed, it's still possible to get a bad
        // fraction error. We want to exclude cases where the time is wrong or
        // maximum fulfilled has already been met. (So this check is
        // over-excluding potentially eligible orders).
        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        if (order.parameters.orderType == OrderType.CONTRACT) {
            return true;
        }

        if (order.denominator == 0) {
            return true;
        }

        return false;
    }

    function ineligibleForNoContract(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // This is kind of lazy. It'd be better to resign a modified order,
        // probably, than to just skip all cases except where it's possible to
        // get away without one.

        // Validation obviates the need for a signature.
        (bool isValidated, , , ) = context.seaport.getOrderStatus(
            context.executionState.orderHashes[orderIndex]
        );

        if (!isValidated) {
            return true;
        }

        if (order.signature.length != 64 && order.signature.length != 65) {
            return true;
        }

        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        if (
            context.executionState.orders.length == 0 ||
            context.executionState.orders[0].parameters.consideration.length ==
            0 ||
            context
                .executionState
                .orders[0]
                .parameters
                .consideration[0]
                .itemType ==
            ItemType.NATIVE
        ) {
            return true;
        }

        if (order.parameters.orderType == OrderType.CONTRACT) {
            return true;
        }

        return false;
    }

    function ineligibleForOrderIsCancelled(
        AdvancedOrder memory order,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            return true;
        }
    }
}

contract FuzzMutations is Test, FuzzExecutor {
    using FuzzEngineLib for FuzzTestContext;
    using OrderEligibilityLib for FuzzTestContext;
    using AdvancedOrderLib for AdvancedOrder;
    using OrderParametersLib for OrderParameters;

    function mutation_invalidSignature(
        FuzzTestContext memory context
    ) external {
        AdvancedOrder memory order = context.mutationState.selectedOrder;

        // TODO: fuzz on size of invalid signature
        order.signature = "";

        exec(context);
    }

    function mutation_invalidSigner_BadSignature(
        FuzzTestContext memory context
    ) external {
        AdvancedOrder memory order = context.mutationState.selectedOrder;

        order.signature[0] = bytes1(uint8(order.signature[0]) ^ 0x01);

        exec(context);
    }

    function mutation_invalidSigner_ModifiedOrder(
        FuzzTestContext memory context
    ) external {
        AdvancedOrder memory order = context.mutationState.selectedOrder;

        order.parameters.salt ^= 0x01;

        exec(context);
    }

    function mutation_badSignatureV(FuzzTestContext memory context) external {
        AdvancedOrder memory order = context.mutationState.selectedOrder;

        order.signature[64] = 0xff;

        exec(context);
    }

    function mutation_invalidTime_NotStarted(
        FuzzTestContext memory context
    ) external {
        AdvancedOrder memory order = context.mutationState.selectedOrder;

        order.parameters.startTime = block.timestamp + 1;
        order.parameters.endTime = block.timestamp + 2;

        exec(context);
    }

    function mutation_invalidTime_Expired(
        FuzzTestContext memory context
    ) external {
        AdvancedOrder memory order = context.mutationState.selectedOrder;

        order.parameters.startTime = block.timestamp - 1;
        order.parameters.endTime = block.timestamp;

        exec(context);
    }

    function mutation_badFraction_NoFill(
        FuzzTestContext memory context
    ) external {
        AdvancedOrder memory order = context.mutationState.selectedOrder;

        order.numerator = 0;

        exec(context);
    }

    function mutation_badFraction_Overfill(
        FuzzTestContext memory context
    ) external {
        AdvancedOrder memory order = context.mutationState.selectedOrder;

        order.numerator = 2;
        order.denominator = 1;

        exec(context);
    }

    function mutation_orderIsCancelled(
        FuzzTestContext memory context
    ) external {
        uint256 orderIndex = context.mutationState.selectedOrderIndex;

        bytes32 orderHash = context.executionState.orderHashes[orderIndex];
        FuzzInscribers.inscribeOrderStatusCancelled(
            orderHash,
            true,
            context.seaport
        );

        exec(context);
    }

    function mutation_noContract(FuzzTestContext memory context) external {
        context.setIneligibleOrders(MutationFilters.ineligibleForNoContract);

        (AdvancedOrder memory order, ) = context.selectEligibleOrder();

        for (uint256 i = 0; i < order.parameters.consideration.length; i++) {
            order.parameters.consideration[i].token = address(0x123456789);
        }

        exec(context);
    }
}

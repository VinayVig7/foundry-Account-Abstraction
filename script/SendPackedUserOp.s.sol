// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {UserOperation} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "../src/Helper/IEntryPoint.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    address constant RECIPIENT = 0x8a6843446334983E8BF1330934B71e01f751e099;

    function run() public {
        // Setup

        HelperConfig helperConfig = new HelperConfig();
        address dest = helperConfig.getConfig().vinayToken; // arbitrum testnet vinayToken address
        uint256 value = 0;
        address minimalAccountAddress = 0xf5e4B417859DEfaFF884a31723DE9bA9B05Bc646;

        bytes memory functionData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            RECIPIENT,
            500e18 // 500 VINAY token (adjust decimals if needed)
        );

        bytes memory executeCalldata = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );

        UserOperation memory userOp = generateSignedUserOperation(
            executeCalldata,
            helperConfig.getConfig(),
            minimalAccountAddress
        );

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        // Send transaction
        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(
            ops,
            payable(helperConfig.getConfig().account)
        );
        vm.stopBroadcast();
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (UserOperation memory) {
        uint256 nonce = vm.getNonce(minimalAccount) + 4; // Fetch current nonce for the sender

        // 1. Generate the unsigned data
        UserOperation memory userOp = _generateUnsignedUserOperation(
            callData,
            minimalAccount,
            nonce
        );

        // 2. Get the userOp Hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(
            userOp
        );

        bytes32 digest = userOpHash.toEthSignedMessageHash(); // same as MessageHashUtils.toEthSignedMessageHash(userOpHash); we are using MessageHashUtils for bytes32;
        // 3. Sign it
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }
        userOp.signature = abi.encodePacked(r, s, v); // Check the order
        return userOp;
    }

    function _generateUnsignedUserOperation(
        bytes memory callData,
        address sender,
        uint256 nonce
    ) internal pure returns (UserOperation memory) {
        // Set realistic gas values for Sepolia
        uint256 callGasLimit = 100_000;
        uint256 verificationGasLimit = 100_000;
        uint256 preVerificationGas = 50_000; // Higher than standard tx to cover bundler overhead

        // Gas fees - adjust based on current Sepolia conditions
        uint256 maxPriorityFeePerGas = 1e9; // 2 Gwei
        uint256 maxFeePerGas = 5e8; // 0.5 Gwei (base fee + priority fee)

        return
            UserOperation({
                sender: sender,
                nonce: nonce,
                initCode: hex"", // Empty for existing accounts
                callData: callData, // The actual execution call
                callGasLimit: callGasLimit,
                verificationGasLimit: verificationGasLimit,
                preVerificationGas: preVerificationGas,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                paymasterAndData: hex"", // No paymaster
                signature: hex"" // Will be filled later
            });
    }
}

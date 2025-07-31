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

contract SignedPackedUSerOperations is Script {
    using MessageHashUtils for bytes32;
    address constant RECIPIENT = 0x8a6843446334983E8BF1330934B71e01f751e099;
    // Token token;

    function run() external {
        // helperConfig = HelperConfig(DevOpsTools.get_most_recent_deployment("HelperConfig", block.chainid));
        HelperConfig helperConfig = new HelperConfig();

        address dest = helperConfig.getConfig().vinayToken;
        // console2.log("the address of the destination contract is: ", dest);
        uint256 value = 0;
        address acc = 0xf5e4B417859DEfaFF884a31723DE9bA9B05Bc646;
        // console2.log("the address of deployed contract is: ", acc);
        bytes memory functionData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            RECIPIENT,
            500e18
        ); // 500 VINAY token (adjust decimals if needed)
        // console2.log("the address of the account contract is: ", helperConfig.getConfig().account);
        // console2.log("the address of the entrypoint contract is: ", helperConfig.getConfig().entryPoint);
        bytes memory executionData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );

        UserOperation memory op = generateSignedUserOperation(
            executionData,
            helperConfig.getConfig(),
            acc
        );
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;

        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(
            ops,
            payable(helperConfig.getConfig().account)
        );
        vm.stopBroadcast();

        // assert(Token(dest).balanceOf(vm.envAddress("ACC")) == 1e18);
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address account
    ) public view returns (UserOperation memory) {
        // uint256 nonce = vm.getNonce(account);
        uint256 nonce = vm.getNonce(account) + 5;
        // IEntryPoint entrypoint = IEntryPoint(config.entryPoint);
        // uint256 nonce = entrypoint.getNonce(account, 0);
        UserOperation memory op = _generateUnsignedUserOperation(
            callData,
            account,
            nonce
        );
        // console2.log("the etnry point address is : ", config.entryPoint);
        bytes32 opHash = IEntryPoint(config.entryPoint).getUserOpHash(op);
        bytes32 digest = opHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;

        uint256 Anvil_Key = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(Anvil_Key, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
            // (v, r, s) = vm.sign(config.account, digest);
        }

        op.signature = abi.encodePacked(r, s, v);
        return op;
    }

    function _generateUnsignedUserOperation(
        bytes memory callData,
        address sender,
        uint256 nonce
    ) internal view returns (UserOperation memory) {
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

// contract fundAA is Script {
//     function run() external {
//         address aa = DevOpsTools.get_most_recent_deployment("EIP4337AA", block.chainid);
//         HelperConfig helperConfig = new HelperConfig();
//         address entryPoint = helperConfig.getConfig().entryPoint;

//         vm.startBroadcast(vm.envUint("PRIV"));
//         (bool ok,) = payable(aa).call{value: 0.03 ether}("");
//         (ok);
//         // IEntryPoint(entryPoint).depositTo{value: 0.01 ether}(aa);
//         vm.stopBroadcast();
//     }
// }

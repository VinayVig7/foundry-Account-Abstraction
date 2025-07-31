// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {Test, console} from "forge-std/Test.sol";
// import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
// import {DeployMinimal} from "script/DeployMinimal.s.sol";
// import {HelperConfig} from "script/HelperConfig.s.sol";
// import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
// import {SendPackedUserOp, UserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";
// import {ECDSA} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
// import {MessageHashUtils} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

// contract MiimalAccountTest is Test {
//     using MessageHashUtils for bytes32;

//     MinimalAccount minimalAccount;
//     HelperConfig helperConfig;
//     ERC20Mock usdc;
//     SendPackedUserOp sendPackedUserOp;

//     address RANDOM_USER = makeAddr("randomuser");
//     uint256 constant AMOUNT = 1e18;

//     function setUp() public {
//         DeployMinimal deployMinimal = new DeployMinimal();
//         (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
//         usdc = new ERC20Mock();
//         sendPackedUserOp = new SendPackedUserOp();
//     }

//     // USDC mint
//     // msg.sender -> MinimalAccount
//     // approve some amount
//     // USDC contract
//     // come from the entryPoint
//     function testOwnerCanExecuteCommands() public {
//         // Arrange
//         assertEq(usdc.balanceOf(address(minimalAccount)), 0);
//         address dest = address(usdc);
//         uint256 value = 0;
//         bytes memory functionData = abi.encodeWithSelector(
//             ERC20Mock.mint.selector,
//             address(minimalAccount),
//             AMOUNT
//         );

//         // Act
//         vm.prank(minimalAccount.owner());
//         minimalAccount.execute(dest, value, functionData);

//         // Assert
//         assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
//     }

//     function testNonOwnerCannotExecuteCommands() public {
//         // Arrange
//         assertEq(usdc.balanceOf(address(minimalAccount)), 0);
//         address dest = address(usdc);
//         uint256 value = 0;
//         bytes memory functionData = abi.encodeWithSelector(
//             ERC20Mock.mint.selector,
//             address(minimalAccount),
//             AMOUNT
//         );

//         // Act
//         vm.prank(RANDOM_USER);

//         // Assert
//         vm.expectRevert(
//             MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector
//         );
//         minimalAccount.execute(dest, value, functionData);
//     }

//     function testRecoverSignedOp() public {
//         // Arrange
//         assertEq(usdc.balanceOf(address(minimalAccount)), 0);
//         address dest = address(usdc);
//         uint256 value = 0;
//         bytes memory functionData = abi.encodeWithSelector(
//             ERC20Mock.mint.selector,
//             address(minimalAccount),
//             AMOUNT
//         );
//         bytes memory executeCallData = abi.encodeWithSelector(
//             minimalAccount.execute.selector,
//             dest,
//             value,
//             functionData
//         );
//         UserOperation memory packedUserOp = sendPackedUserOp
//             .generateSignedUserOperation(
//                 executeCallData,
//                 helperConfig.getConfig(),
//                 address(minimalAccount)
//             );
//         bytes32 userOperationHash = IEntryPoint(
//             helperConfig.getConfig().entryPoint
//         ).getUserOpHash(packedUserOp);

//         // Act
//         address actualSigner = ECDSA.recover(
//             userOperationHash.toEthSignedMessageHash(),
//             packedUserOp.signature
//         );

//         // Assert
//         assertEq(actualSigner, minimalAccount.owner());
//     }

//     function testValidationOfUserOps() public {
//         // Arrange
//         assertEq(usdc.balanceOf(address(minimalAccount)), 0);
//         address dest = address(usdc);
//         uint256 value = 0;
//         bytes memory functionData = abi.encodeWithSelector(
//             ERC20Mock.mint.selector,
//             address(minimalAccount),
//             AMOUNT
//         );
//         bytes memory executeCallData = abi.encodeWithSelector(
//             minimalAccount.execute.selector,
//             dest,
//             value,
//             functionData
//         );
//         UserOperation memory packedUserOp = sendPackedUserOp
//             .generateSignedUserOperation(
//                 executeCallData,
//                 helperConfig.getConfig(),
//                 address(minimalAccount)
//             );
//         bytes32 userOperationHash = IEntryPoint(
//             helperConfig.getConfig().entryPoint
//         ).getUserOpHash(packedUserOp);
//         uint256 missingAccountFunds = 1e18;

//         // Act
//         vm.prank(helperConfig.getConfig().entryPoint);
//         uint256 validationData = minimalAccount.validateUserOp(
//             packedUserOp,
//             userOperationHash,
//             missingAccountFunds
//         ); /* In our case validateData is returning only boolean 1(fail), 0(success) but we should pack validationData  */

//         // Assert
//         assertEq(validationData, 0);
//     }

//     function testEntryPointCanExecuteCommands() public {
//         // Arrange
//         assertEq(usdc.balanceOf(address(minimalAccount)), 0);
//         address dest = address(usdc);
//         uint256 value = 0;
//         bytes memory functionData = abi.encodeWithSelector(
//             ERC20Mock.mint.selector,
//             address(minimalAccount),
//             AMOUNT
//         );
//         bytes memory executeCallData = abi.encodeWithSelector(
//             minimalAccount.execute.selector,
//             dest,
//             value,
//             functionData
//         );
//         UserOperation memory packedUserOp = sendPackedUserOp
//             .generateSignedUserOperation(
//                 executeCallData,
//                 helperConfig.getConfig(),
//                 address(minimalAccount)
//             );
//         // bytes32 userOperationHash = IEntryPoint(
//         //     helperConfig.getConfig().entryPoint
//         // ).getUserOpHash(packedUserOp); /* This is handled by handleOps */

//         vm.deal(address(minimalAccount), 1e18);
//         UserOperation[] memory ops = new UserOperation[](1);
//         ops[0] = packedUserOp;

//         // Act
//         vm.prank(RANDOM_USER);
//         IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(
//             ops,
//             payable(RANDOM_USER)
//         );

//         // Assert
//         assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
//     }
// }

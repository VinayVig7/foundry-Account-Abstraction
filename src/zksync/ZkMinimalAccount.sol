// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// zkSync Era Imports
import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {Transaction, MemoryTransactionHelper} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {NONCE_HOLDER_SYSTEM_CONTRACT, BOOTLOADER_FORMAL_ADDRESS, DEPLOYER_SYSTEM_CONTRACT} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {Utils} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

// OZ Imports
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
/**
 * Lifecycle of a type 113 (0x71 transaction)
 * msg.sender is the bootloader system contract
 *
 * Phase 1 Validation
 * 1. The user sends the transaction to the "zkSync API client" (sort of a "Light node")
 * 2. The zkSync API client checks to see the nonce is unique by querrying the NonceHolder sytem contract
 * 3. The zkSync API client calls validateTransection, which must update the nonce
 * 4. The zkSync API client checks the nonce is updated
 * 5. The zkSync API client calls payForTransection, or prepareForPaymaster & validateAndPayForPaymasterTransection
 * 6. The zkSync API client verifies that the bootLoader gets paid
 *
 * Phase 2 Execution
 * 7. The zkSync API client passes the validated transaction to the main node / sequencer (as of today, they are the same)
 * 8. The main node calls executedTransection
 * 9. If a paymaster was used, the postTransaction is called
 */
contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    ////////////
    // Errors //
    ///////////
    error ZkMinimalAccount__NotEnoughBalance();
    error ZkMinimalAccount__NotFromBootLoader();
    error ZkMinimalAccount__ExecutionFailed();
    error ZkMinimalAccount__NotFromBootLoaderOrOwner();
    error ZkMinimalAccount__FailedToPay();
    error ZkMinimalAccount__InvalidSignature();

    ///////////////
    // Modifiers //
    //////////////
    modifier requireFromBootLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZkMinimalAccount__NotFromBootLoaderOrOwner();
        }
        _;
    }

    ///////////////
    // Functions //
    //////////////
    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    ////////////////////////
    // External Functions //
    ///////////////////////
    /**
     * @notice must increase the nonce
     * @notice must validate the transection (check the owner signed the transaction)
     * @notice also check to see if we have enough money in our account
     */
    function validateTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction memory _transaction
    ) external payable requireFromBootLoader returns (bytes4 magic) {
        return _validateTransaction(_transaction);
    }

    function executeTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction memory _transaction
    ) external payable requireFromBootLoaderOrOwner {
        _executeTransaction(_transaction);
    }

    // you sign a tx
    // send the signed tx to your friend
    // They can send it by calling this function

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    function executeTransactionFromOutside(
        Transaction memory _transaction
    ) external payable {
        bytes4 magic = _validateTransaction(_transaction);
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            revert ZkMinimalAccount__InvalidSignature();
        }
        _executeTransaction(_transaction);
    }

    function payForTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction memory _transaction
    ) external payable {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZkMinimalAccount__FailedToPay();
        }
    }

    function prepareForPaymaster(
        bytes32 _txHash,
        bytes32 _possibleSignedHash,
        Transaction memory _transaction
    ) external payable {}

    ////////////////////////
    // Internal Functions //
    ///////////////////////
    function _validateTransaction(
        Transaction memory _transaction
    ) internal returns (bytes4 magic) {
        // Call nonceholder
        // Increment nonce
        // call(x, y, z) -> system contract call
        // is_system has been set to true in foundry.toml which has relation with nonce updation. Check cyfrin documentry related to this topic. Video number 26 in account abstraction
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(
                INonceHolder.incrementMinNonceIfEquals,
                (_transaction.nonce)
            )
        );

        // Check for fee to pay
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) {
            revert ZkMinimalAccount__NotEnoughBalance();
        }

        // Check the signature
        bytes32 txHash = _transaction.encodeHash();
        // bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash); // We dont have to do this
        address signer = ECDSA.recover(txHash, _transaction.signature);
        bool isValidSigner = signer == owner();
        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }

        // return the "magic" number
        return magic;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(
                gas,
                to,
                value,
                data
            );
        } else {
            bool success;
            assembly {
                success := call(
                    gas(),
                    to,
                    value,
                    add(data, 0x20),
                    mload(data),
                    0,
                    0
                )
            }
            if (!success) {
                revert ZkMinimalAccount__ExecutionFailed();
            }
        }
    }
}

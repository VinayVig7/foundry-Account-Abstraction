// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address vinayToken;
        address account;
    }

    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337; // Anvil default
    address constant BURNER_WALLET = 0xA17551985a9d16c7FfaC10F0D199833a78c33E58;
    // address constant FOUNDRY_DEFAULT_WALLET =
    //     0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address constant ANVIL_DEFAULT_WALLET =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ARBITRUM_SEPOLIA_CHAIN_ID] = getArbitrumSepoliaConfig();
        networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSyncSepoliaConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
                vinayToken: 0x0cB363CcF15e70c224B1Fe809be4DcAe56C7f59C, // This CA is for arbitrum still need to deploy on eth
                account: BURNER_WALLET
            });
    }

    function getArbitrumSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
                vinayToken: 0x0cB363CcF15e70c224B1Fe809be4DcAe56C7f59C, // This is listed on arb seploia
                account: BURNER_WALLET
            });
    }

    function getZkSyncSepoliaConfig()
        public
        pure
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                entryPoint: address(0),
                vinayToken: 0x0cB363CcF15e70c224B1Fe809be4DcAe56C7f59C, // Need to be listed on zksync
                account: BURNER_WALLET
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        // deploy mocks
        console2.log("Deploying mocks...");
        vm.startBroadcast(ANVIL_DEFAULT_WALLET);
        EntryPoint entryPoint = new EntryPoint();
        ERC20Mock erc20Mock = new ERC20Mock();
        vm.stopBroadcast();
        // I did changes on my own Patrick said there is some mistake i dont know if i did right or wrong i figured out that we were not returning localNetworkConfig. In comments there is patrick code
        /*
            return NetworkConfig({
                entryPoint: address(entryPoint),
                account: FOUNDRY_DEFAULT_WALLET
            });
         */
        localNetworkConfig = NetworkConfig({
            entryPoint: address(entryPoint),
            vinayToken: address(erc20Mock),
            account: ANVIL_DEFAULT_WALLET
        });
        return localNetworkConfig;
    }
}

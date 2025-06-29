// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract Helper {
    // mapping(SupportedNetworks enumValue => string humanReadableName) public networks;
    mapping(uint256 => string humanReadableName) public networks;

    // BlockChainIDs
    uint256 constant BlockChainIDEthereumSepolia = 11155111;
    uint256 constant BlockChainIDAvalancheFuji = 43113; // Avalanche Fuji Testnet Chain ID

    // chainlink chainSelector
    uint64 constant chainIdEthereumSepolia = 16015286601757825753;
    uint64 constant chainIdAvalancheFuji = 14767482510784806043;

    // Router addresses
    address constant routerEthereumSepolia = 0xD0daae2231E9CB96b94C8512223533293C3693Bf;
    address constant routerAvalancheFuji = 0xF694E193200268f9a4868e4Aa017A0118C9a8177;

    // Link addresses (can be used as fee)
    address constant linkEthereumSepolia = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant linkAvalancheFuji = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;

    // Wrapped native addresses
    address constant wethEthereumSepolia = 0x7b79995e5f793a07Bc00c21412e50eA00A789691;
    address constant wavaxAvalancheFuji = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;

    // CCIP-BnM addresses
    address constant ccipBnMAvalancheFuji = 0xD21341536c5cF5EB1bcb58f6723cE26e8D8E90e4;

    // USDC addresses
    address constant usdcAvalancheFuji = 0x5425890298aed601595a70AB815c96711a31Bc65;

    constructor() {
        networks[BlockChainIDAvalancheFuji] = "Avalanche Fuji";
    }

    function getPriceFeeds(uint256 blockChainID)
        internal
        pure
        returns (address ethUsdPriceFeed, address usdCusdPriceFeed)
    {
        if (blockChainID == BlockChainIDAvalancheFuji) {
            // TODO: Add price feeds for Avalanche Fuji
        }
    }

    function getConfigFromNetwork(uint256 blockChainID)
        internal
        pure
        returns (address router, address linkToken, address wrappedNative, uint64 chainId)
    {
        if (blockChainID == BlockChainIDAvalancheFuji) {
            return (routerAvalancheFuji, linkAvalancheFuji, wavaxAvalancheFuji, chainIdAvalancheFuji);
        } else if (blockChainID == BlockChainIDEthereumSepolia) {
            return (routerEthereumSepolia, linkEthereumSepolia, wethEthereumSepolia, chainIdEthereumSepolia);
        }
    }
}
//     internal
//     pure
//     returns (address router, address linkToken, address wrappedNative, uint64 chainId)
// {
//     if (network == SupportedNetworks.ETHEREUM_SEPOLIA) {
//         return (routerEthereumSepolia, linkEthereumSepolia, wethEthereumSepolia, chainIdEthereumSepolia);
//     } else if (network == SupportedNetworks.ARBITRUM_SEPOLIA) {
//         return (routerArbitrumSepolia, linkArbitrumSepolia, wethArbitrumSepolia, chainIdArbitrumSepolia);
//     } else if (network == SupportedNetworks.AVALANCHE_FUJI) {
//         return (routerAvalancheFuji, linkAvalancheFuji, wavaxAvalancheFuji, chainIdAvalancheFuji);
//     } else if (network == SupportedNetworks.POLYGON_MUMBAI) {
//         return (routerPolygonMumbai, linkPolygonMumbai, wmaticPolygonMumbai, chainIdPolygonMumbai);
//     } else if (network == SupportedNetworks.BNB_CHAIN_TESTNET) {
//         return (routerBnbChainTestnet, linkBnbChainTestnet, wbnbBnbChainTestnet, chainIdBnbChainTestnet);
//     } else if (network == SupportedNetworks.OPTIMISM_SEPOLIA) {
//         return (routerOptimismSepolia, linkOptimismSepolia, wethOptimismSepolia, chainIdOptimismSepolia);
//     } else if (network == SupportedNetworks.BASE_SEPOLIA) {
//         return (routerBaseSepolia, linkBaseSepolia, wethBaseSepolia, chainIdBaseSepolia);
//     } else if (network == SupportedNetworks.WEMIX_TESTNET) {
//         return (routerWemixTestnet, linkWemixTestnet, wwemixWemixTestnet, chainIdWemixTestnet);
//     } else if (network == SupportedNetworks.KROMA_SEPOLIA_TESTNET) {
//         return (
//             routerKromaSepoliaTestnet, linkKromaSepoliaTestnet, wethKromaSepoliaTestnet, chainIdKromaSepoliaTestnet
//         );
//     } else if (network == SupportedNetworks.METIS_SEPOLIA) {
//         return (routerMetisSepolia, linkMetisSepolia, wethMetisSepolia, chainIdMetisSepolia);
//     } else if (network == SupportedNetworks.ZKSYNC_SEPOLIA) {
//         return (routerZksyncSepolia, linkZksyncSepolia, wethZksyncSepolia, chainIdZksyncSepolia);
//     } else if (network == SupportedNetworks.SCROLL_SEPOLIA) {
//         return (routerScrollSepolia, linkScrollSepolia, wethScrollSepolia, chainIdScrollSepolia);
//     } else if (network == SupportedNetworks.ZIRCUIT_SEPOLIA) {
//         return (routerZircuitSepolia, linkZircuitSepolia, wethZircuitSepolia, chainIdZircuitSepolia);
//     } else if (network == SupportedNetworks.XLAYER_SEPOLIA) {
//         return (routerXlayerSepolia, linkXlayerSepolia, wokbXlayerSepolia, chainIdXlayerSepolia);
//     } else if (network == SupportedNetworks.POLYGON_ZKEVM_SEPOLIA) {
//         return (
//             routerPolygonZkevmSepolia, linkPolygonZkevmSepolia, wethPolygonZkevmSepolia, chainIdPolygonZkevmSepolia
//         );
//     } else if (network == SupportedNetworks.POLKADOT_ASTAR_SHIBUYA) {
//         return (
//             routerPolkadotAstarShibuya,
//             linkPolkadotAstarShibuya,
//             wsbyPolkadotAstarShibuya,
//             chainIdPolkadotAstarShibuya
//         );
//     } else if (network == SupportedNetworks.MANTLE_SEPOLIA) {
//         return (routerMantleSepolia, linkMantleSepolia, wmntMantleSepolia, chainIdMantleSepolia);
//     } else if (network == SupportedNetworks.SONEIUM_MINATO_SEPOLIA) {
//         return (
//             routerSoneiumMinatoSepolia,
//             linkSoneiumMinatoSepolia,
//             wethSoneiumMinatoSepolia,
//             chainIdSoneiumMinatoSepolia
//         );
//     } else if (network == SupportedNetworks.BSQUARED_TESTNET) {
//         return (routerBsquaredTestnet, linkBsquaredTestnet, wbtcBsquaredTestnet, chainIdBsquaredTestnet);
//     } else if (network == SupportedNetworks.BOB_SEPOLIA) {
//         return (routerBobSepolia, linkBobSepolia, wethBobSepolia, chainIdBobSepolia);
//     } else if (network == SupportedNetworks.WORLDCHAIN_SEPOLIA) {
//         return (routerWorldchainSepolia, linkWorldchainSepolia, wethWorldchainSepolia, chainIdWorldchainSepolia);
//     } else if (network == SupportedNetworks.SHIBARIUM_TESTNET) {
//         return (routerShibariumTestnet, linkShibariumTestnet, wboneShibariumTestnet, chainIdShibariumTestnet);
//     } else if (network == SupportedNetworks.BITLAYER_TESTNET) {
//         return (routerBitlayerTestnet, linkBitlayerTestnet, wbtcBitlayerTestnet, chainIdBitlayerTestnet);
//     } else if (network == SupportedNetworks.FANTOM_SONIC_TESTNET) {
//         return (routerFantomSonicTestnet, linkFantomSonicTestnet, wethFantomSonicTestnet, chainIdFantomSonicTestnet);
//     } else if (network == SupportedNetworks.CORN_TESTNET) {
//         return (routerCornTestnet, linkCornTestnet, wbtcCornTestnet, chainIdCornTestnet);
//     } else if (network == SupportedNetworks.HASHKEY_SEPOLIA) {
//         return (routerHashkeySepolia, linkHashkeySepolia, whskHashkeySepolia, chainIdHashkeySepolia);
//     } else if (network == SupportedNetworks.INK_SEPOLIA) {
//         return (routerInkSepolia, linkInkSepolia, wethInkSepolia, chainIdInkSepolia);
//     }
// }

"use client"

import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"
import { useState, useEffect, useCallback } from "react"
import { useToast } from "@/hooks/use-toast"
import { ethers } from "ethers"
import BorrowManagementABI from "../../abi/BorrowManagement.json"
import CollManagementABI from "../../abi/CollManagement.json"

const BORROW_MANAGEMENT_ADDRESS = "0xae4E4BDdE6Eb2F040aB9d34EA74086b3a8311389"
const COLL_MANAGEMENT_ADDRESS = "0xd4aa953485eF4f1A916e42b9350Ab510f0920465"
const WETH_ADDRESS = "0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764"
const BORROW_USDC = "0x9A133558fF7349f7721f3dD2b0E193e55ae9A3F1"
const CHAIN_IDS = { FUJI: 43113, SEPOLIA: 11155111 }

// Chainlink WETH/USD Price Feed on Sepolia
const WETH_PRICE_FEED = "0x694AA1769357215DE4FAC081bf1f309aDC325306"
const CHAINLINK_DECIMALS = 8

const TOKEN_SYMBOLS = {
  [BORROW_USDC]: "USDC",
  [WETH_ADDRESS]: "WETH",
  [ethers.ZeroAddress]: "None",
}

export function AvailableBorrowing() {
  const [available, setAvailable] = useState("0")
  const [collateralInfo, setCollateralInfo] = useState({ collateralToken: "None", amount: "0" })
  const { toast } = useToast()

  const fetchAvailable = useCallback(async () => {
    if (!window.ethereum) {
      toast({ title: "Error", description: "No wallet detected", variant: "destructive" })
      return
    }
    try {
      const provider = new ethers.BrowserProvider(window.ethereum)
      const signer = await provider.getSigner()
      const userAddress = await signer.getAddress()
      const network = await provider.getNetwork()
      const chainId = Number(network.chainId)
      console.log("Detected Chain ID:", chainId)

      // Enforce Sepolia for borrow page
      if (chainId !== CHAIN_IDS.SEPOLIA) {
        toast({ title: "Error", description: `Please switch to Sepolia (Chain ID: ${CHAIN_IDS.SEPOLIA})`, variant: "destructive" })
        return
      }

      // Query BorrowManagement.sol on Fuji
      let collateralToken = "None"
      let borrowToken = BORROW_USDC // Default to USDC
      try {
        const fujiProvider = new ethers.JsonRpcProvider("https://api.avax-test.network/ext/bc/C/rpc")
        const borrowContract = new ethers.Contract(BORROW_MANAGEMENT_ADDRESS, BorrowManagementABI.abi, fujiProvider)
        const balanceInfo = await borrowContract.availableBorrowTokenBalance(userAddress)
        console.log("Balance info:", balanceInfo)
        console.log("Raw balance fields:", {
          collateralToken: balanceInfo[0],
          borrowToken: balanceInfo[1],
          initiator: balanceInfo[2],
          sourceChainId: balanceInfo[3]?.toString(),
          pendingAmount: balanceInfo[4]?.toString(),
          borrowedAmount: balanceInfo[5]?.toString(),
          status: balanceInfo[6]?.toString(),
          proof: balanceInfo[7],
          updatedAt: balanceInfo[8]?.toString(),
        })
        collateralToken = TOKEN_SYMBOLS[balanceInfo[0]] || "None"
        // Workaround for zero borrowToken
        borrowToken = balanceInfo[1] !== ethers.ZeroAddress ? TOKEN_SYMBOLS[balanceInfo[1]] || "Unknown" : "USDC"
        if (balanceInfo[1] === ethers.ZeroAddress) {
          console.warn("BorrowManagement.sol returned zero borrowToken, defaulting to USDC");
        }
      } catch (borrowError) {
        console.error("Error fetching borrow balance:", borrowError)
        collateralToken = "WETH" // Fallback
        toast({ title: "Error", description: "Failed to fetch borrow balance", variant: "destructive" })
      }

      // Query CollManagement.sol on Sepolia
      let creditLimit = 0
      let collateralValueUSD = 0
      try {
        const sepoliaProvider = new ethers.JsonRpcProvider("https://ethereum-sepolia-rpc.publicnode.com")
        const collContract = new ethers.Contract(COLL_MANAGEMENT_ADDRESS, CollManagementABI.abi, sepoliaProvider)
        const collateralInfo = await collContract.userCollateral(userAddress, WETH_ADDRESS)
        const priceFeedAddress = await collContract.getPriceFeed(WETH_ADDRESS)
        console.log("Collateral info:", {
          totalDeposited: collateralInfo.totalDeposited.toString(),
          totalBorrowed: collateralInfo.totalBorrowed.toString(),
          priceFeed: priceFeedAddress,
        })

        const wethAmount = ethers.formatUnits(collateralInfo.totalDeposited, 18) // WETH decimals
        let wethPriceUSD = 0
        if (priceFeedAddress === ethers.ZeroAddress) {
          console.warn("Price feed not set for WETH, using Chainlink fallback")
          const priceFeed = new ethers.Contract(WETH_PRICE_FEED, [
            "function latestRoundData() view returns (uint80, int256, uint256, uint256, uint80)",
            "function decimals() view returns (uint8)"
          ], sepoliaProvider)
          const [ , price, , , ] = await priceFeed.latestRoundData()
          wethPriceUSD = Number(ethers.formatUnits(price, CHAINLINK_DECIMALS))
        } else {
          const priceFeed = new ethers.Contract(priceFeedAddress, [
            "function latestRoundData() view returns (uint80, int256, uint256, uint256, uint80)",
            "function decimals() view returns (uint8)"
          ], sepoliaProvider)
          const [ , price, , , ] = await priceFeed.latestRoundData()
          const priceFeedDecimals = await priceFeed.decimals()
          wethPriceUSD = Number(ethers.formatUnits(price, priceFeedDecimals))
        }
        collateralValueUSD = Number(wethAmount) * wethPriceUSD
        creditLimit = collateralValueUSD / 1.5 // liquidationThreshold = 150%
      } catch (collError) {
        console.error("Error fetching collateral:", collError)
        const sepoliaProvider = new ethers.JsonRpcProvider("https://rpc.sepolia.org")
        const priceFeed = new ethers.Contract(WETH_PRICE_FEED, [
          "function latestRoundData() view returns (uint80, int256, uint256, uint256, uint80)",
          "function decimals() view returns (uint8)"
        ], sepoliaProvider)
        const [ , price, , , ] = await priceFeed.latestRoundData()
        const wethPriceUSD = Number(ethers.formatUnits(price, CHAINLINK_DECIMALS))
        collateralValueUSD = (5 * wethPriceUSD) // Fallback: 5 WETH
        creditLimit = collateralValueUSD / 1.5
        collateralToken = "WETH"
        toast({ title: "Warning", description: "Using fallback collateral data (5 WETH)", variant: "default" })
      }

      const decimals = 6 // USDC decimals
      setAvailable(creditLimit.toFixed(decimals))
      setCollateralInfo({
        collateralToken,
        amount: collateralValueUSD.toFixed(decimals),
      })
    } catch (error) {
      console.error("Error fetching available borrow:", error)
      toast({ title: "Error", description: "Failed to fetch available borrow amount", variant: "destructive" })
    }
  }, [])

  useEffect(() => {
    fetchAvailable()
  }, [fetchAvailable])

  useEffect(() => {
    const test = async () => {
      const fujiProvider = new ethers.JsonRpcProvider("https://api.avax-test.network/ext/bc/C/rpc");
      const borrowContract = new ethers.Contract(BORROW_MANAGEMENT_ADDRESS, BorrowManagementABI.abi, fujiProvider);
      try {
        const borrowToken = await borrowContract.BORROW_USDC();
        console.log("Borrow Token:", borrowToken);
      } catch (error) {
        console.error("Error fetching BORROW_USDC:", error);
      }
    };
    test();
  }, [BORROW_MANAGEMENT_ADDRESS, BorrowManagementABI.abi]);

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white">Available Borrowing</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex justify-between text-sm">
          <span className="text-gray-400">Borrow Token</span>
          <span className="text-white">USDC</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-gray-400">Available to Borrow</span>
          <span className="text-teal-400">{available} USDC</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-gray-400">Collateral Token</span>
          <span className="text-white">{collateralInfo.collateralToken}</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-gray-400">Collateral Value</span>
          <span className="text-white">{collateralInfo.amount} USDC</span>
        </div>
      </CardContent>
    </Card>
  )
}
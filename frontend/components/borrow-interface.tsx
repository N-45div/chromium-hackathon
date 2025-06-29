"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { useState, useEffect, useCallback } from "react"
import { useToast } from "@/hooks/use-toast"
import { AlertTriangle } from "lucide-react"
import { ethers } from "ethers"
import BorrowManagementABI from "../../abi/BorrowManagement.json"
import CollManagementABI from "../../abi/CollManagement.json"

const BORROW_MANAGEMENT_ADDRESS = "0xae4E4BDdE6Eb2F040aB9d34EA74086b3a8311389"
const BORROW_USDC = "0x9A133558fF7349f7721f3dD2b0E193e55ae9A3F1"
const COLL_MANAGEMENT_ADDRESS = "0xd4aa953485eF4f1A916e42b9350Ab510f0920465"
const WETH_ADDRESS = "0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764"
const CHAIN_IDS = { FUJI: 43113, SEPOLIA: 11155111 }

export function BorrowInterface() {
  const [selectedToken, setSelectedToken] = useState("")
  const [amount, setAmount] = useState("")
  const [available, setAvailable] = useState("0")
  const [isCorrectChain, setIsCorrectChain] = useState(false)
  const [isInitialized, setIsInitialized] = useState(false)
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

      if (chainId !== CHAIN_IDS.SEPOLIA) {
        toast({ title: "Warning", description: `Please switch to Sepolia (Chain ID: ${CHAIN_IDS.SEPOLIA}) for collateral data`, variant: "default" })
      } else {
        setIsCorrectChain(true)
      }

      // Check borrow initialization on Fuji
      const fujiProvider = new ethers.JsonRpcProvider("https://api.avax-test.network/ext/bc/C/rpc")
      const borrowContract = new ethers.Contract(BORROW_MANAGEMENT_ADDRESS, BorrowManagementABI.abi, fujiProvider)
      let balanceInfo
      try {
        balanceInfo = await borrowContract.availableBorrowTokenBalance(userAddress)
        console.log("Raw balanceInfo:", balanceInfo)
        const balanceFields = {
          collateralToken: balanceInfo[0] || ethers.ZeroAddress,
          borrowToken: balanceInfo[1] || ethers.ZeroAddress,
          initiator: balanceInfo[2] || ethers.ZeroAddress,
          sourceChainId: balanceInfo[3]?.toString() || "0",
          pendingAmount: balanceInfo[4]?.toString() || "0",
          borrowedAmount: balanceInfo[5]?.toString() || "0",
          status: balanceInfo[6]?.toString() || "0",
          proof: balanceInfo[7] || "0x",
          originalDepositor: balanceInfo[8] || ethers.ZeroAddress,
          recipientForZK: balanceInfo[9] || ethers.ZeroAddress,
          ownChainSelector: balanceInfo[10]?.toString() || "0",
          updatedAt: balanceInfo[11]?.toString() || "0",
          merkleRoot: balanceInfo[12] || "0x",
        }
        console.log("Balance info:", balanceFields)
        if (balanceFields.status !== "1") {
          toast({ title: "Warning", description: "Borrow not initialized. Attempting to borrow may fail.", variant: "default" })
        } else {
          setIsInitialized(true)
        }
      } catch (borrowError) {
        console.error("Error fetching borrow balance:", borrowError)
        toast({ title: "Error", description: "Failed to fetch borrow balance", variant: "destructive" })
      }

      const sepoliaProvider = new ethers.JsonRpcProvider("https://ethereum-sepolia-rpc.publicnode.com")
      const collContract = new ethers.Contract(COLL_MANAGEMENT_ADDRESS, CollManagementABI.abi, sepoliaProvider)
      const collateralInfo = await collContract.userCollateral(userAddress, WETH_ADDRESS)
      const priceFeedAddress = await collContract.priceFeeds(WETH_ADDRESS)
      console.log("Collateral info:", {
        totalDeposited: collateralInfo.totalDeposited.toString(),
        totalBorrowed: collateralInfo.totalBorrowed.toString(),
        priceFeed: priceFeedAddress,
      })

      const wethAmount = ethers.formatUnits(collateralInfo.totalDeposited, 18)
      let wethPriceUSD = 0
      const priceFeed = new ethers.Contract(
        priceFeedAddress,
        ["function latestRoundData() view returns (uint80, int256, uint256, uint256, uint80)", "function decimals() view returns (uint8)"],
        sepoliaProvider
      )
      const [, price, , ,] = await priceFeed.latestRoundData()
      const priceFeedDecimals = await priceFeed.decimals()
      wethPriceUSD = Number(ethers.formatUnits(price, priceFeedDecimals))
      const collateralValueUSD = Number(wethAmount) * wethPriceUSD
      const creditLimit = collateralValueUSD / 1.5
      setAvailable(creditLimit.toFixed(6))
    } catch (error) {
      console.error("Error fetching available borrow:", error)
      toast({ title: "Error", description: "Failed to fetch available borrow amount", variant: "destructive" })
    }
  }, [])

  useEffect(() => {
    fetchAvailable()
  }, [fetchAvailable])

  const handleBorrow = async () => {
    if (!selectedToken || !amount) {
      toast({ title: "Error", description: "Please select a token and enter an amount", variant: "destructive" })
      return
    }
    try {
      if (!window.ethereum) throw new Error("MetaMask not found")
      const provider = new ethers.BrowserProvider(window.ethereum)
      const signer = await provider.getSigner()
      const userAddress = await signer.getAddress()
      const network = await provider.getNetwork()
      console.log("Borrow attempt:", {
        userAddress,
        chainId: Number(network.chainId),
        selectedToken,
        amount,
        available,
      })
      if (Number(network.chainId) !== CHAIN_IDS.FUJI) {
        toast({ title: "Warning", description: `Please switch to Fuji (Chain ID: ${CHAIN_IDS.FUJI}) for borrowing`, variant: "default" })
      }
      const contract = new ethers.Contract(BORROW_MANAGEMENT_ADDRESS, BorrowManagementABI.abi, signer)
      const parsedAmount = ethers.parseUnits(amount, 6)
      if (Number(parsedAmount) > Number(ethers.parseUnits(available, 6))) {
        toast({ title: "Error", description: "Borrow amount exceeds available balance", variant: "destructive" })
        return
      }
      console.log("Sending borrowApply transaction:", { amount: parsedAmount.toString(), gasLimit: 300000 })
      const tx = await contract.borrowApply(parsedAmount, { gasLimit: 300000 })
      console.log("Transaction sent:", { txHash: tx.hash, from: tx.from, to: tx.to, data: tx.data })
      toast({ title: "Borrow Request Sent", description: `Tx Hash: ${tx.hash}` })
      const receipt = await tx.wait()
      console.log("Transaction receipt:", {
        status: receipt.status,
        gasUsed: receipt.gasUsed.toString(),
        logs: receipt.logs,
        blockNumber: receipt.blockNumber,
      })
      toast({ title: "Borrow Confirmed", description: `Borrowed: ${amount} USDC` })
    } catch (error) {
      console.error("Borrow error:", {
        message: error.message,
        reason: error.reason,
        code: error.code,
        data: error.data,
      })
      toast({ title: "Borrow Failed", description: error.reason || error.message || "An unexpected error occurred", variant: "destructive" })
    }
  }

  const healthFactor = amount ? (2.45 - Number.parseFloat(amount) / 50000).toFixed(2) : "2.45"
  const liquidationPrice = amount ? (1800 - Number.parseFloat(amount) / 10).toFixed(0) : "1800"

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white">Borrow Interface</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        {!isInitialized && (
          <Alert className="border-yellow-500 bg-yellow-500/10">
            <AlertTriangle className="h-4 w-4 text-yellow-500" />
            <AlertDescription className="text-yellow-200">
              Borrowing not initialized. Attempting to borrow may fail.
            </AlertDescription>
          </Alert>
        )}
        <div className="space-y-2">
          <Label className="text-gray-300">Borrow Token</Label>
          <Select value={selectedToken} onValueChange={setSelectedToken}>
            <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
              <SelectValue placeholder="Select token to borrow" />
            </SelectTrigger>
            <SelectContent className="bg-slate-700 border-slate-600">
              <SelectItem value="USDC" className="text-white hover:bg-slate-600">
                <div className="flex items-center justify-between w-full">
                  <span>USD Coin</span>
                  <span className="text-teal-400 ml-2">8.5%</span>
                </div>
              </SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-2">
          <Label className="text-gray-300">Amount</Label>
          <div className="relative">
            <Input
              type="number"
              placeholder="0.0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="bg-slate-700 border-slate-600 text-white pr-16"
            />
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="absolute right-2 top-1/2 transform -translate-y-1/2 text-teal-400 hover:text-teal-300"
              onClick={() => setAmount(available)}
            >
              MAX
            </Button>
          </div>
          <p className="text-sm text-gray-400">Available: {available} USDC</p>
        </div>
        {selectedToken && amount && (
          <div className="space-y-4">
            <div className="p-4 bg-slate-700/50 rounded-lg space-y-2">
              <h4 className="text-white font-medium">Health Factor Impact</h4>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Current Health Factor</span>
                <span className="text-green-400">2.45</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">New Health Factor</span>
                <span
                  className={`${Number.parseFloat(healthFactor) > 1.5 ? "text-green-400" : Number.parseFloat(healthFactor) > 1.2 ? "text-yellow-400" : "text-red-400"}`}
                >
                  {healthFactor}
                </span>
              </div>
            </div>
            <div className="p-4 bg-slate-700/50 rounded-lg space-y-2">
              <h4 className="text-white font-medium">Loan Terms</h4>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Interest Rate</span>
                <span className="text-white">8.5%</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Liquidation Price</span>
                <span className="text-white">${liquidationPrice} ETH</span>
              </div>
            </div>
            {Number.parseFloat(healthFactor) < 1.5 && (
              <Alert className="border-yellow-500 bg-yellow-500/10">
                <AlertTriangle className="h-4 w-4 text-yellow-500" />
                <AlertDescription className="text-yellow-200">
                  Warning: This borrow amount will significantly reduce your health factor. Consider borrowing less to maintain a safer position.
                </AlertDescription>
              </Alert>
            )}
          </div>
        )}
        <Button
          onClick={handleBorrow}
          className="w-full bg-orange-600 hover:bg-orange-700"
          disabled={!selectedToken || !amount}
        >
          Borrow USDC
        </Button>
      </CardContent>
    </Card>
  )
}
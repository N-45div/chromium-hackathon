"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { useState, useEffect } from "react"
import { useToast } from "@/hooks/use-toast"
import { AlertTriangle } from "lucide-react"
import {ethers} from 'ethers'
import BorrowManagementABI from '../../abi/BorrowManagement.json'

const BORROW_MANAGEMENT_ADDRESS = "0xd4aa953485eF4f1A916e42b9350Ab510f0920465"
const BORROW_USDC = '0x5425890298a76a5fDE71C00E1554ebb843aB41d2'
const CHAIN_IDS = {
  FUJI: 43113
}
//const borrowTokens = [{ symbol: "USDC", name: "USD Coin", apy: "8.5%", available: "18750" }]

export function BorrowInterface() {
  const [selectedToken, setSelectedToken] = useState("")
  const [amount, setAmount] = useState("")
  const [available, setAvailable] = useState('0')
  const [isCorrectChain, setIsCorrectChain] = useState(false)
  const { toast } = useToast()

  useEffect(() => {
    const fetchAvailable = async () => {
      if (!window.ethereum) return
      try {
        const provider = new ethers.BrowserProvider(window.ethereum)
        const signer = await provider.getSigner()
        const userAddress = await signer.getAddress()
        const network = provider.getNetwork()
        const chainId = Number(network.chainId)

        if (chainId !== CHAIN_IDS.FUJI) {
          toast({title: "Error", description: "Please switch to Avalanche Fuji", variant: "destructive"})
          return
        }
        setIsCorrectChain(true)

        const contract = new ethers.Contract(BORROW_MANAGEMENT_ADDRESS, BorrowManagementABI, provider)
        const balanceInfo = await contract.availableBorrowTokenBalance(userAddress)
        const decimals = 6 //USDC decimals
        setAvailable(ethers.formatUnits(balanceInfo.borrowedAmoun, decimals))
      } catch (error) {
        console.error("Error fetching available borrow: ", error)
        toast({title: "Error", description: "Failed to fetch available borrow amount", variant: "destructive"})
      }
    }
    fetchAvailable()
  }, [])

  // const handleBorrow = () => {
  //   if (!selectedToken || !amount) {
  //     toast({
  //       title: "Error",
  //       description: "Please select a token and enter an amount",
  //       variant: "destructive",
  //     })
  //     return
  //   }

  //   toast({
  //     title: "Borrow Request Initiated",
  //     description: `Borrowing ${amount} ${selectedToken}`,
  //   })
  // }

  const handleBorrow = async () => {
    if (!selectedToken || !amount) {
      toast({title: "Error", description: "Please select a token and enter an amount", variant: "destructive"})
      return
    }
    if (!isCorrectChain) {
      toast({title: "Error", description: "Please switch to Avalanche Fuji", variant: "destructive"})
      return
    }
    try {
      if (!window.ethereum) throw new Error("MetaMask not found")
      const provider = new ethers.BrowserProvider(window.ethereum)
      const signer = await provider.getSigner()
      const contract = new ethers.Contract(BORROW_MANAGEMENT_ADDRESS, BorrowManagementABI, signer)
      const parsedAmount = ethers.parseUnits(available, 6)
      if (parsedAmount > availableAmount) {
        toast({title: "Error", description: "Borrow amount exceeds available balance", variant: "destructive"})
        return
      }
      const tx = await contract.borrowApply(parsedAmount, {gasLimit: 500000})
      toast({title: "Borrow Request Sent", description: `Tx Hash: ${tx.hash}`})
      await tx.wait()
      toast({title: "Borrow Confirmed", description: `Borrowed: ${amount} USDC`})
    } catch (error: any) {
      console.error("Borrow error: ", error)
      toast({title: "Borrow Failed", description: error.reason || error.message || "An unexpected error occurred", variant: "destructive"})
    }
  }


//  const selectedTokenData = borrowTokens.find((t) => t.symbol === selectedToken)
  const healthFactor = amount ? (2.45 - Number.parseFloat(amount) / 50000).toFixed(2) : "2.45"
  const liquidationPrice = amount ? (1800 - Number.parseFloat(amount) / 10).toFixed(0) : "1800"

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white">Borrow Interface</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
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
          disabled={!selectedToken || !amount || !isCorrectChain}
        >
          Borrow USDC
        </Button>
      </CardContent>
    </Card>
  )
}

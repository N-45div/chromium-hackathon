"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useState, useEffect } from "react"
import { useToast } from "@/hooks/use-toast"
import { ethers } from 'ethers'
import CollManagementABI from '../../abi/CollManagement.json'

const COLL_MANAGEMENT_ADDRESS = '0xd4aa953485eF4f1A916e42b9350Ab510f0920465'
const TOKEN_ADDRESSES = {
  WETH: '0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764', // WETH on Sepolia
  BNB: '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd' // WBNB on BNB Testnet
}
const CHAIN_IDS = {
  SEPOLIA: 11155111, // Sepolia
  BNB: 97 // BNB Testnet
}
const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)"
]
const tokens = [
  { symbol: "WETH", name: "Wrapped Ether", chainId: CHAIN_IDS.SEPOLIA },
  { symbol: "BNB", name: "BNB Chain", chainId: CHAIN_IDS.BNB, disabled: true }
]

export function DepositForm() {
  const [selectedToken, setSelectedToken] = useState("WETH")
  const [amount, setAmount] = useState("")
  const [recipient, setRecipient] = useState("") // Added for Fuji recipient
  const [balance, setBalance] = useState('0')
  const [isCorrectChain, setIsCorrectChain] = useState(false)
  const { toast } = useToast()

  useEffect(() => {
    const fetchBalance = async () => {
      if (!window.ethereum) return
      try {
        const provider = new ethers.BrowserProvider(window.ethereum)
        const signer = await provider.getSigner()
        const userAddress = await signer.getAddress()
        const network = await provider.getNetwork()
        const chainId = Number(network.chainId)

        if (chainId !== CHAIN_IDS.SEPOLIA) {
          toast({ title: "Error", description: "Please switch to Sepolia", variant: "destructive" })
          setIsCorrectChain(false)
          return
        }
        setIsCorrectChain(true)

        const contract = new ethers.Contract(TOKEN_ADDRESSES.WETH, ERC20_ABI, provider)
        const balance = await contract.balanceOf(userAddress)
        const decimals = await contract.decimals()
        setBalance(ethers.formatUnits(balance, decimals))
        setRecipient(userAddress) // Default recipient to user
      } catch (error) {
        console.error("Error fetching balance:", error)
        toast({ title: "Error", description: "Failed to fetch balance", variant: "destructive" })
      }
    }
    fetchBalance()
  }, [])

  const handleApprove = async () => {
    if (!window.ethereum) {
      toast({ title: "Error", description: "Wallet not found", variant: "destructive" })
      return
    }
    if (!isCorrectChain) {
      toast({ title: "Error", description: "Please switch to Sepolia", variant: "destructive" })
      return
    }
    try {
      const provider = new ethers.BrowserProvider(window.ethereum)
      const signer = await provider.getSigner()
      const tokenContract = new ethers.Contract(TOKEN_ADDRESSES.WETH, ERC20_ABI, signer)
      const parsedAmount = ethers.parseUnits(amount || "0", 18)
      const allowance = await tokenContract.allowance(await signer.getAddress(), COLL_MANAGEMENT_ADDRESS)
      if (allowance >= parsedAmount) {
        toast({ title: "Approval Not Needed", description: "Already approved" })
        return
      }
      const tx = await tokenContract.approve(COLL_MANAGEMENT_ADDRESS, parsedAmount, { gasLimit: 100000 })
      toast({ title: "Approval Sent", description: `Tx Hash: ${tx.hash}` })
      await tx.wait()
      toast({ title: "Approval Confirmed", description: "Token approval successful" })
    } catch (error: any) {
      console.error("Approval error:", error)
      toast({ title: "Approval Failed", description: error.message || "Failed to approve token", variant: "destructive" })
    }
  }

  // const test = async () => {
  //   const provider = new ethers.BrowserProvider(window.ethereum);
  //   const contract = new ethers.Contract('0xd4aa953485eF4f1A916e42b9350Ab510f0920465', CollManagementABI.abi, provider);
  //   const userAddress = '0x76ACa6a6B825683408d28B71ed11d5463fA1496F';
  //   const collateralToken = '0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764'; // WETH
  //   const userCollateral = await contract.userCollateral(userAddress, collateralToken);
  //   console.log('Deposited WETH:', ethers.formatUnits(userCollateral.totalDeposited, 18));
  // }

  const handleDeposit = async () => {
    if (!selectedToken || !amount || !recipient) {
      toast({ title: "Error", description: "Please select a token, enter an amount, and specify a recipient", variant: "destructive" })
      return
    }
    if (!isCorrectChain) {
      toast({ title: "Error", description: "Please switch to Sepolia", variant: "destructive" })
      return
    }
    try {
      if (!window.ethereum) throw new Error('Wallet not found')
      const provider = new ethers.BrowserProvider(window.ethereum)
      const signer = await provider.getSigner()
      const userAddress = await signer.getAddress()
      const contract = new ethers.Contract(COLL_MANAGEMENT_ADDRESS, CollManagementABI.abi, signer)
      const parsedAmount = ethers.parseUnits(amount, 18)
      const tokenContract = new ethers.Contract(TOKEN_ADDRESSES.WETH, ERC20_ABI, provider)
      const allowance = await tokenContract.allowance(userAddress, COLL_MANAGEMENT_ADDRESS)
      if (allowance < parsedAmount) {
        toast({ title: "Approval Required", description: "Please approve the token first", variant: "destructive" })
        return
      }
      const tx = await contract.depositCollateral(TOKEN_ADDRESSES.WETH, parsedAmount, recipient, { gasLimit: 300000 })
      toast({ title: "Transaction Sent", description: `Tx Hash: ${tx.hash}` })
      await tx.wait()
      toast({ title: "Deposit Confirmed", description: "Collateral successfully deposited" })
    } catch (error: any) {
      console.error("Deposit error:", error)
      toast({ title: "Deposit Failed", description: error.reason || error.message || "An unexpected error occurred", variant: "destructive" })
    }
  }

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardContent className="space-y-6">
        <div className="space-y-2z">
          <Label htmlFor="token" className="text-gray-300">Collateral Token</Label>
          <Select value={selectedToken} onValueChange={setSelectedToken}>
            <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
              <SelectValue placeholder="Select token" />
            </SelectTrigger>
            <SelectContent className="bg-slate-700 border-slate-600">
              {tokens.map((token) => (
                <SelectItem key={token.symbol} value={token.symbol} className="text-white hover:bg-slate-600" disabled={token.disabled}>
                  <div className="flex items-center space-x-2">
                    <div className="w-6 h-6 bg-gradient-to-br from-teal-400 to-cyan-400 rounded-full flex items-center justify-center"></div>
                    <span>{token.name}</span>
                  </div>
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-2">
          <Label htmlFor="amount" className="text-gray-300">Amount</Label>
          <div className="relative">
            <Input
              id="amount"
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
              onClick={() => setAmount(balance)}
            >
              MAX
            </Button>
          </div>
          <p className="text-sm text-gray-400">Balance: {balance} WETH</p>
        </div>
        <div className="space-y-2">
          <Label htmlFor="recipient" className="text-gray-300">Fuji Recipient Address</Label>
          <Input
            id="recipient"
            type="text"
            placeholder="0x..."
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            className="bg-slate-700 border-slate-600 text-white"
          />
        </div>
        {selectedToken && amount && recipient && (
          <div className="p-4 bg-slate-700/50 rounded-lg space-y-2">
            <h4 className="text-white font-medium">Transaction Preview</h4>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Depositing</span>
              <span className="text-white">{amount} WETH</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Recipient</span>
              <span className="text-white">{recipient}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Network Fee</span>
              <span className="text-white">~$12.50</span>
            </div>
          </div>
        )}
        <div className="space-x-2 flex">
          <Button
            onClick={handleApprove}
            className="w-1/2 bg-teal-600 hover:bg-teal-700"
            disabled={!selectedToken || !amount || !recipient || !isCorrectChain}
          >
            Approve Token
          </Button>
          <Button
            onClick={handleDeposit}
            className="w-1/2 bg-teal-600 hover:bg-teal-700"
            disabled={!selectedToken || !amount || !recipient || !isCorrectChain}
          >
            Deposit Collateral
          </Button>
          {/* <button onClick={test}>Test</button> */}
        </div>
      </CardContent>
    </Card>
  )
}
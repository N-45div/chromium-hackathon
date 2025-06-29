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
import PrivacyProxyABI from '../../abi/PrivacyProxy.json'

const COLL_MANAGEMENT_ADDRESS = '0xd4aa953485eF4f1A916e42b9350Ab510f0920465'
const PRIVACY_PROXY_ADDRESS = '0xB4b8b2ed36407eE96A42954308E023fA9eAe2437'
const TOKEN_ADDRESSES = {
  WETH: '0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764',
  BNB: '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd'
}
const CHAIN_IDS = {
  SEPOLIA: 11155111,
  BNB: 97
}
const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)"
]
const PRICE_FEED_ABI = [
  "function latestRoundData() view returns (uint80, int256, uint256, uint256, uint80)",
  "function decimals() view returns (uint8)"
]
const ETH_USD_PRICE_FEED = '0x694AA1769357215DE4FAC081bf1f309aDC325306' // Chainlink ETH/USD on Sepolia
const tokens = [
  { symbol: "WETH", name: "Wrapped Ether", chainId: CHAIN_IDS.SEPOLIA },
  { symbol: "BNB", name: "BNB Chain", chainId: CHAIN_IDS.BNB, disabled: true }
]

export function DepositForm() {
  const [selectedToken, setSelectedToken] = useState("WETH")
  const [amount, setAmount] = useState("")
  const [recipient, setRecipient] = useState("")
  const [balance, setBalance] = useState('0')
  const [isCorrectChain, setIsCorrectChain] = useState(false)
  const [usePrivateDeposit, setUsePrivateDeposit] = useState(false)
  const [networkFee, setNetworkFee] = useState('0.00')
  const { toast } = useToast()

  useEffect(() => {
    const fetchBalanceAndFee = async () => {
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
        setRecipient(userAddress)

        // Estimate network fee
        const rpcProvider = new ethers.JsonRpcProvider("https://ethereum-sepolia-rpc.publicnode.com")
        const feeData = await rpcProvider.getFeeData()
        const gasPrice = feeData.gasPrice ?? feeData.maxFeePerGas ?? BigInt(0)
        const gasLimit = usePrivateDeposit ? 1000000 : 300000
        const gasCost = gasPrice * BigInt(gasLimit)

        const ethPriceContract = new ethers.Contract(ETH_USD_PRICE_FEED, PRICE_FEED_ABI, provider)
        const [, ethPrice,,,] = await ethPriceContract.latestRoundData()
        const priceDecimals = await ethPriceContract.decimals()
        const ethPriceUSD = Number(ethers.formatUnits(ethPrice, priceDecimals))

        const gasCostETH = Number(ethers.formatUnits(gasCost, 18))
        const feeUSD = (gasCostETH * ethPriceUSD).toFixed(4)
        setNetworkFee(feeUSD)
        console.log("Gas Price:", gasPrice.toString(), "Wei")
        console.log("ETH Price (USD):", ethPriceUSD)
        console.log("Fee USD:", feeUSD)
        setNetworkFee(feeUSD)

      } catch (error) {
        console.error("Error fetching balance or fee:", error)
        toast({ title: "Error", description: "Failed to fetch balance or network fee", variant: "destructive" })
      }
    }
    fetchBalanceAndFee()
  }, [amount, usePrivateDeposit])

  const generateCommitment = async () => {
    const nullifier = ethers.hexlify(ethers.randomBytes(32))
    const secret = ethers.hexlify(ethers.randomBytes(32))
    const commitment = ethers.keccak256(ethers.concat([nullifier, secret]))
    return commitment
  }

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
      const userAddress = await signer.getAddress()
      const tokenContract = new ethers.Contract(TOKEN_ADDRESSES.WETH, ERC20_ABI, signer)
      const parsedAmount = ethers.parseUnits(amount || "0", 18)
      const targetAddress = usePrivateDeposit ? PRIVACY_PROXY_ADDRESS : COLL_MANAGEMENT_ADDRESS
      const allowance = await tokenContract.allowance(userAddress, targetAddress)
      if (allowance >= parsedAmount) {
        toast({ title: "Approval Not Needed", description: "Already approved" })
        return
      }
      const tx = await tokenContract.approve(targetAddress, parsedAmount, { gasLimit: 100000 })
      toast({ title: "Approval Sent", description: `Tx Hash: ${tx.hash}` })
      await tx.wait()
      toast({ title: "Approval Confirmed", description: "Token approval successful" })
    } catch (error: any) {
      console.error("Approval error:", error)
      toast({ title: "Approval Failed", description: error.message || "Failed to approve token", variant: "destructive" })
    }
  }

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
      const parsedAmount = ethers.parseUnits(amount, 18)
      const tokenContract = new ethers.Contract(TOKEN_ADDRESSES.WETH, ERC20_ABI, provider)
      const targetAddress = usePrivateDeposit ? PRIVACY_PROXY_ADDRESS : COLL_MANAGEMENT_ADDRESS
      const allowance = await tokenContract.allowance(userAddress, targetAddress)
      if (allowance < parsedAmount) {
        toast({ title: "Approval Required", description: `Please approve ${usePrivateDeposit ? "PrivacyProxy" : "CollManagement"} for ${amount} WETH`, variant: "destructive" })
        return
      }

      if (usePrivateDeposit) {
        const contract = new ethers.Contract(PRIVACY_PROXY_ADDRESS, PrivacyProxyABI.abi, signer)
        const commitment = await generateCommitment()
        console.log("Depositing with commitment:", commitment)
        const balance = await tokenContract.balanceOf(userAddress)
        if (balance < parsedAmount) {
          throw new Error(`Insufficient WETH balance: ${ethers.formatUnits(balance, 18)} WETH`)
        }
        const tx = await contract.deposit(TOKEN_ADDRESSES.WETH, parsedAmount, commitment, { gasLimit: 1000000 })
        toast({ title: "Private Deposit Sent", description: `Tx Hash: ${tx.hash}` })
        await tx.wait()
        toast({ title: "Private Deposit Confirmed", description: "Collateral deposited privately via PrivacyProxy" })
      } else {
        const contract = new ethers.Contract(COLL_MANAGEMENT_ADDRESS, CollManagementABI.abi, signer)
        const tx = await contract.depositCollateral(TOKEN_ADDRESSES.WETH, parsedAmount, recipient, { gasLimit: 300000 })
        toast({ title: "Transaction Sent", description: `Tx Hash: ${tx.hash}` })
        await tx.wait()
        toast({ title: "Deposit Confirmed", description: "Collateral successfully deposited" })
      }
    } catch (error: any) {
      console.error("Deposit error:", error.message, error)
      toast({ title: "Deposit Failed", description: error.reason || error.message || "Transaction reverted", variant: "destructive" })
    }
  }

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white">Deposit Collateral</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="space-y-2">
          <Label className="text-gray-300">Deposit Type</Label>
          <Select value={usePrivateDeposit ? "private" : "public"} onValueChange={(value) => setUsePrivateDeposit(value === "private")}>
            <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
              <SelectValue placeholder="Select deposit type" />
            </SelectTrigger>
            <SelectContent className="bg-slate-700 border-slate-600">
              <SelectItem value="public" className="text-white hover:bg-slate-600">Public Deposit</SelectItem>
              <SelectItem value="private" className="text-white hover:bg-slate-600">Private Deposit (ZK)</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-2">
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
              <span className="text-gray-400">Deposit Type</span>
              <span className="text-white">{usePrivateDeposit ? "Private (ZK)" : "Public"}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Network Fee</span>
              <span className="text-white">${networkFee}</span>
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
            {usePrivateDeposit ? "Deposit Privately" : "Deposit Collateral"}
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
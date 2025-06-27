"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useState, useEffect } from "react"
import { useToast } from "@/hooks/use-toast"
import { ArrowRight } from "lucide-react"
import { ethers } from 'ethers'
import CollManagementABI from '../../abi/CollManagement.json'

const COLL_MANAGEMENT_ADDRESS = '0xd4aa953485eF4f1A916e42b9350Ab510f0920465'
const TOKEN_ADDRESSES = {
  ETH: '0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764',
  BNB: '0xPLACEHOLDER_BNB',
  AVAX: '0xPLACEHOLDER_AVAX'
}
const BORROW_TOKEN_ADDRESS = "0x5425890298a76a5fDE71C00E1554ebb843aB41d2"
const CHAIN_IDS = {
  SEPOLIA: 11155111,
  BNB: 97,
  FUJI: 43113
}
const chains = [
  { id: "sepolia", name: "Sepolia", chainId: CHAIN_IDS.SEPOLIA, tokens: ["ETH"] },
  { id: "bnb", name: "BNB Chain", chainId: CHAIN_IDS.BNB, tokens: ["BNB"], disabled: true },
  { id: "avalanche", name: "Avalanche Fuji", chainId: CHAIN_IDS.FUJI, tokens: ["AVAX"], disabled: false },
]
const borrowTokens = ["USDC"]
const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)"
]

export function AdvancedDepositForm() {
  const [sourceChain, setSourceChain] = useState("")
  const [targetChain, setTargetChain] = useState("")
  const [collateralToken, setCollateralToken] = useState("")
  const [borrowToken, setBorrowToken] = useState("")
  const [amount, setAmount] = useState("")
  const [recipient, setRecipient] = useState("")
  const [recipientSignature, setRecipientSignature] = useState("")
  const [balance, setBalance] = useState('0')
  const [isCorrectChain, setIsCorrectChain] = useState(false)
  const [availableProviders, setAvailableProviders] = useState([])
  const { toast } = useToast()

  useEffect(() => {
    // EIP-6963: Detect wallet providers
    const handleProviderDiscovery = (event) => {
      const { info, provider } = event.detail
      setAvailableProviders((prev) => [...prev, { info, provider }])
    }
    window.addEventListener('eip6963:announceProvider', handleProviderDiscovery)
    window.dispatchEvent(new Event('eip6963:requestProvider'))
    return () => window.removeEventListener('eip6963:announceProvider', handleProviderDiscovery)
  }, [])

  useEffect(() => {
    const fetchBalance = async () => {
      if (!window.ethereum || !sourceChain || sourceChain !== 'sepolia') return
      try {
        const provider = new ethers.BrowserProvider(window.ethereum)
        const signer = await provider.getSigner()
        const userAddress = await signer.getAddress()
        const network = await provider.getNetwork()
        const chainId = Number(network.chainId)

        if (chainId !== CHAIN_IDS.SEPOLIA) {
          toast({ title: "Error", description: "Please switch sender wallet to Sepolia", variant: "destructive" })
          return
        }
        setIsCorrectChain(true)

        const contract = new ethers.Contract(TOKEN_ADDRESSES.ETH, ERC20_ABI, provider)
        const balance = await contract.balanceOf(userAddress)
        const decimals = await contract.decimals()
        setBalance(ethers.formatUnits(balance, decimals))
      } catch (error) {
        console.error("Error fetching balance:", error)
        toast({ title: "Error", description: "Failed to fetch balance", variant: "destructive" })
      }
    }
    fetchBalance()
  }, [sourceChain])

  const handleApprove = async () => {
    if (!window.ethereum) {
      toast({ title: "Error", description: "Sender wallet not found", variant: "destructive" })
      return
    }
    if (sourceChain !== 'sepolia') {
      toast({ title: "Error", description: "Only Sepolia is supported as source", variant: "destructive" })
      return
    }
    try {
      const provider = new ethers.BrowserProvider(window.ethereum)
      const signer = await provider.getSigner()
      const tokenContract = new ethers.Contract(TOKEN_ADDRESSES.ETH, ERC20_ABI, signer)
      const parsedAmount = ethers.parseUnits(amount, 18)
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
      console.error("Approval error: ", error)
      toast({ title: "Approval Failed", description: error.message || "Failed to approve token", variant: "destructive" })
    }
  }

  const requestRecipientSignature = async () => {
    if (!recipient || !ethers.isAddress(recipient)) {
      toast({ title: "Error", description: "Invalid recipient address", variant: "destructive" })
      return
    }
    if (availableProviders.length === 0) {
      toast({ title: "Error", description: "No wallet providers detected", variant: "destructive" })
      return
    }
    try {
      // Prompt user to select a provider
      const providerOptions = availableProviders.map(p => p.info.name).join(', ')
      const selectedProviderName = prompt(`Select recipient wallet: ${providerOptions}`)
      const selectedProvider = availableProviders.find(p => p.info.name === selectedProviderName)
      if (!selectedProvider) {
        toast({ title: "Error", description: "No valid wallet selected", variant: "destructive" })
        return
      }

      // Use selected provider
      const recipientProvider = new ethers.BrowserProvider(selectedProvider.provider)
      await recipientProvider.send('eth_requestAccounts', [])
      await recipientProvider.send('wallet_switchEthereumChain', [{ chainId: `0x${CHAIN_IDS.FUJI.toString(16)}` }])
      const recipientSigner = await recipientProvider.getSigner()
      const recipientAddress = await recipientSigner.getAddress()
      if (recipientAddress.toLowerCase() !== recipient.toLowerCase()) {
        toast({ title: "Error", description: "Recipient wallet address does not match", variant: "destructive" })
        return
      }

      // Create message to sign
      const depositInfo = {
        collateralToken: TOKEN_ADDRESSES.ETH,
        amount: ethers.parseUnits(amount || "0", 18),
        targetChainId: targetChain === 'sepolia' ? CHAIN_IDS.SEPOLIA.toString() : CHAIN_IDS.FUJI.toString(),
        borrowToken: BORROW_TOKEN_ADDRESS,
        recipientAddress: recipient,
        commitmentHash: ethers.keccak256(ethers.toUtf8Bytes("mock-commitment"))
      }
      const message = ethers.solidityPackedKeccak256(
        ["address", "uint256", "uint256", "address", "address", "bytes32"],
        [
          depositInfo.collateralToken,
          depositInfo.amount,
          depositInfo.targetChainId,
          depositInfo.borrowToken,
          depositInfo.recipientAddress,
          depositInfo.commitmentHash
        ]
      )

      // Sign with recipient wallet
      const signature = await recipientSigner.signMessage(ethers.getBytes(message))
      setRecipientSignature(signature)
      toast({ title: "Signature Obtained", description: `Recipient signature received from ${selectedProviderName}` })
    } catch (error: any) {
      console.error("Signature error:", error)
      toast({ title: "Signature Failed", description: error.message || "Failed to obtain recipient signature", variant: "destructive" })
    }
  }

  const handleDeposit = async () => {
    if (!sourceChain || !targetChain || !collateralToken || !borrowToken || !amount) {
      toast({ title: "Error", description: "Please fill in all required fields", variant: "destructive" })
      return
    }
    if (sourceChain !== "sepolia") {
      toast({ title: "Error", description: "Only Sepolia is supported as source", variant: "destructive" })
      return
    }
    if (!['sepolia', 'avalanche'].includes(targetChain)) {
      toast({ title: "Error", description: "Only Sepolia and Avalanche Fuji are supported as target", variant: "destructive" })
      return
    }
    if (!isCorrectChain) {
      toast({ title: "Error", description: "Please switch sender wallet to Sepolia", variant: "destructive" })
      return
    }
    if (recipient && !recipientSignature && recipient.toLowerCase() !== (await (await new ethers.BrowserProvider(window.ethereum).getSigner()).getAddress()).toLowerCase()) {
      toast({ title: "Error", description: "Recipient signature required", variant: "destructive" })
      return
    }
    try {
      if (!window.ethereum) throw new Error('Sender wallet not found')
      const provider = new ethers.BrowserProvider(window.ethereum)
      const signer = await provider.getSigner()
      const contract = new ethers.Contract(COLL_MANAGEMENT_ADDRESS, CollManagementABI, signer)
      const parsedAmount = ethers.parseUnits(amount, 18)
      const tokenContract = new ethers.Contract(TOKEN_ADDRESSES.ETH, ERC20_ABI, provider)
      const allowance = await tokenContract.allowance(await signer.getAddress(), COLL_MANAGEMENT_ADDRESS)
      if (allowance < parsedAmount) {
        toast({ title: "Approval Required", description: "Please approve the token first", variant: "destructive" })
        return
      }
      const depositInfo = [
        TOKEN_ADDRESSES.ETH,
        parsedAmount,
        targetChain === 'sepolia' ? CHAIN_IDS.SEPOLIA.toString() : CHAIN_IDS.FUJI.toString(),
        BORROW_TOKEN_ADDRESS,
        recipient || await signer.getAddress(),
        recipientSignature || ('0x' + '0'.repeat(64)),
        ethers.keccak256(ethers.toUtf8Bytes("mock-commitment"))
      ]
      const tx = await contract["depositCollateral((address,uint256,uint256,address,address,bytes,bytes32))"](depositInfo, { gasLimit: 500000 })
      toast({ title: "Transaction Sent", description: `Tx Hash: ${tx.hash}` })
      await tx.wait()
      toast({ title: "Deposit Confirmed", description: "Cross-chain deposit successful" })
    } catch (error: any) {
      console.error("Deposit error: ", error)
      toast({ title: "Deposit Failed", description: error.reason || error.message || "An unexpected error occurred", variant: "destructive" })
    }
  }

  const sourceChainData = chains.find((c) => c.id === sourceChain)
  const collateralRatio = amount ? (Number.parseFloat(amount) * 0.75).toFixed(2) : "0"

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white">Advanced Cross-Chain Deposit</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="space-y-2">
            <Label className="text-gray-300">Source Chain</Label>
            <Select value={sourceChain} onValueChange={setSourceChain}>
              <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
                <SelectValue placeholder="Select source chain" />
              </SelectTrigger>
              <SelectContent className="bg-slate-700 border-slate-600">
                {chains.map((chain) => (
                  <SelectItem key={chain.id} value={chain.id} className="text-white hover:bg-slate-600" disabled={chain.disabled}>
                    {chain.name} {chain.disabled ? "(Coming Soon)" : ""}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label className="text-gray-300">Target Chain</Label>
            <Select value={targetChain} onValueChange={setTargetChain}>
              <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
                <SelectValue placeholder="Select target chain" />
              </SelectTrigger>
              <SelectContent className="bg-slate-700 border-slate-600">
                {chains
                  .filter((c) => c.id !== sourceChain)
                  .map((chain) => (
                    <SelectItem key={chain.id} value={chain.id} className="text-white hover:bg-slate-600" disabled={chain.disabled}>
                      {chain.name} {chain.disabled ? "(Coming Soon)" : ""}
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="space-y-2">
            <Label className="text-gray-300">Collateral Token</Label>
            <Select value={collateralToken} onValueChange={setCollateralToken} disabled={!sourceChain}>
              <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
                <SelectValue placeholder="Select collateral" />
              </SelectTrigger>
              <SelectContent className="bg-slate-700 border-slate-600">
                {sourceChainData?.tokens.map((token) => (
                  <SelectItem key={token} value={token} className="text-white hover:bg-slate-600">
                    {token}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label className="text-gray-300">Borrow Token</Label>
            <Select value={borrowToken} onValueChange={setBorrowToken}>
              <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
                <SelectValue placeholder="Select borrow token" />
              </SelectTrigger>
              <SelectContent className="bg-slate-700 border-slate-600">
                {borrowTokens.map((token) => (
                  <SelectItem key={token} value={token} className="text-white hover:bg-slate-600">
                    {token}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
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
              onClick={() => setAmount(balance)}
            >
              MAX
            </Button>
          </div>
          {sourceChain === "sepolia" && <p className="text-sm text-gray-400">Balance: {balance} WETH</p>}
        </div>

        <div className="space-y-2">
          <Label className="text-gray-300">Recipient Address (Optional)</Label>
          <Input
            placeholder="0x..."
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            className="bg-slate-700 border-slate-600 text-white"
          />
        </div>

        {recipient && recipient.toLowerCase() !== (async () => (await (await new ethers.BrowserProvider(window.ethereum).getSigner()).getAddress()).toLowerCase())() && (
          <Button
            onClick={requestRecipientSignature}
            className="w-full bg-blue-600 hover:bg-blue-700"
            disabled={!recipient || !amount || availableProviders.length === 0}
          >
            Request Recipient Signature (Fuji)
          </Button>
        )}

        {amount && collateralToken && (
          <div className="p-4 bg-slate-700/50 rounded-lg space-y-3">
            <h4 className="text-white font-medium">Risk Calculator</h4>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Collateral Value</span>
              <span className="text-white">{amount} {collateralToken}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Max Borrowing Power</span>
              <span className="text-teal-400">${collateralRatio} {borrowToken}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Collateral Ratio</span>
              <span className="text-green-400">75%</span>
            </div>
          </div>
        )}

        {sourceChain && targetChain && (
          <div className="p-4 bg-slate-700/50 rounded-lg">
            <h4 className="text-white font-medium mb-3">Transaction Flow</h4>
            <div className="flex items-center justify-between text-sm">
              <div className="text-center">
                <div className="w-8 h-8 bg-teal-600 rounded-full flex items-center justify-center mx-auto mb-1">
                  <span className="text-white text-xs">1</span>
                </div>
                <span className="text-gray-400">Deposit on {sourceChainData?.name}</span>
              </div>
              <ArrowRight className="text-gray-500" />
              <div className="text-center">
                <div className="w-8 h-8 bg-teal-600 rounded-full flex items-center justify-center mx-auto mb-1">
                  <span className="text-white text-xs">2</span>
                </div>
                <span className="text-gray-400">CCIP Bridge</span>
              </div>
              <ArrowRight className="text-gray-500" />
              <div className="text-center">
                <div className="w-8 h-8 bg-teal-600 rounded-full flex items-center justify-center mx-auto mb-1">
                  <span className="text-white text-xs">3</span>
                </div>
                <span className="text-gray-400">Borrow on {chains.find((c) => c.id === targetChain)?.name}</span>
              </div>
            </div>
          </div>
        )}

        <div className="flex space-x-2">
          <Button
            onClick={handleApprove}
            className="w-1/2 bg-teal-600 hover:bg-teal-700"
            disabled={!sourceChain || !collateralToken || !amount || !isCorrectChain || sourceChain !== "sepolia"}
          >
            Approve Token
          </Button>
          <Button
            onClick={handleDeposit}
            className="w-1/2 bg-teal-600 hover:bg-teal-700"
            disabled={!sourceChain || !targetChain || !collateralToken || !borrowToken || !amount || !isCorrectChain || sourceChain !== "sepolia"}
          >
            Execute Cross-Chain Deposit
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
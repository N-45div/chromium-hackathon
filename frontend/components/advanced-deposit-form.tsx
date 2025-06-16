"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useState } from "react"
import { useToast } from "@/hooks/use-toast"
import { ArrowRight } from "lucide-react"

const chains = [
  { id: "ethereum", name: "Ethereum", tokens: ["ETH"] },
  { id: "bnb", name: "BNB Chain", tokens: ["BNB"] },
  { id: "avalanche", name: "Avalanche", tokens: ["AVAX"] },
]

const borrowTokens = ["USDC"]

export function AdvancedDepositForm() {
  const [sourceChain, setSourceChain] = useState("")
  const [targetChain, setTargetChain] = useState("")
  const [collateralToken, setCollateralToken] = useState("")
  const [borrowToken, setBorrowToken] = useState("")
  const [amount, setAmount] = useState("")
  const [recipient, setRecipient] = useState("")
  const { toast } = useToast()

  const handleDeposit = () => {
    if (!sourceChain || !targetChain || !collateralToken || !borrowToken || !amount) {
      toast({
        title: "Error",
        description: "Please fill in all required fields",
        variant: "destructive",
      })
      return
    }

    toast({
      title: "Cross-Chain Deposit Initiated",
      description: `Depositing ${amount} ${collateralToken} on ${sourceChain} for ${borrowToken} borrowing on ${targetChain}`,
    })
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
                  <SelectItem key={chain.id} value={chain.id} className="text-white hover:bg-slate-600">
                    {chain.name}
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
                    <SelectItem key={chain.id} value={chain.id} className="text-white hover:bg-slate-600">
                      {chain.name}
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
          <Input
            type="number"
            placeholder="0.0"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="bg-slate-700 border-slate-600 text-white"
          />
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

        {amount && collateralToken && (
          <div className="p-4 bg-slate-700/50 rounded-lg space-y-3">
            <h4 className="text-white font-medium">Risk Calculator</h4>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Collateral Value</span>
              <span className="text-white">
                {amount} {collateralToken}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Max Borrowing Power</span>
              <span className="text-teal-400">
                ${collateralRatio} {borrowToken}
              </span>
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

        <Button
          onClick={handleDeposit}
          className="w-full bg-teal-600 hover:bg-teal-700"
          disabled={!sourceChain || !targetChain || !collateralToken || !borrowToken || !amount}
        >
          Execute Cross-Chain Deposit
        </Button>
      </CardContent>
    </Card>
  )
}

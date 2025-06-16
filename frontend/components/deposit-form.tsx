"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useState } from "react"
import { useToast } from "@/hooks/use-toast"

const tokens = [
  { symbol: "ETH", name: "Ethereum", balance: "12.5" },
  { symbol: "BNB", name: "BNB Chain", balance: "45.2" },
]

export function DepositForm() {
  const [selectedToken, setSelectedToken] = useState("")
  const [amount, setAmount] = useState("")
  const { toast } = useToast()

  const handleDeposit = () => {
    if (!selectedToken || !amount) {
      toast({
        title: "Error",
        description: "Please select a token and enter an amount",
        variant: "destructive",
      })
      return
    }

    toast({
      title: "Deposit Initiated",
      description: `Depositing ${amount} ${selectedToken} as collateral`,
    })
  }

  const selectedTokenData = tokens.find((t) => t.symbol === selectedToken)

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white">Simple Deposit</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="space-y-2">
          <Label htmlFor="token" className="text-gray-300">
            Collateral Token
          </Label>
          <Select value={selectedToken} onValueChange={setSelectedToken}>
            <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
              <SelectValue placeholder="Select token" />
            </SelectTrigger>
            <SelectContent className="bg-slate-700 border-slate-600">
              {tokens.map((token) => (
                <SelectItem key={token.symbol} value={token.symbol} className="text-white hover:bg-slate-600">
                  <div className="flex items-center space-x-2">
                    <div className="w-6 h-6 bg-gradient-to-br from-teal-400 to-cyan-400 rounded-full flex items-center justify-center">
                      <span className="text-white font-bold text-xs">{token.symbol}</span>
                    </div>
                    <span>{token.name}</span>
                  </div>
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="amount" className="text-gray-300">
            Amount
          </Label>
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
              onClick={() => selectedTokenData && setAmount(selectedTokenData.balance)}
            >
              MAX
            </Button>
          </div>
          {selectedTokenData && (
            <p className="text-sm text-gray-400">
              Balance: {selectedTokenData.balance} {selectedToken}
            </p>
          )}
        </div>

        {selectedToken && amount && (
          <div className="p-4 bg-slate-700/50 rounded-lg space-y-2">
            <h4 className="text-white font-medium">Transaction Preview</h4>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Depositing</span>
              <span className="text-white">
                {amount} {selectedToken}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Network Fee</span>
              <span className="text-white">~$12.50</span>
            </div>
          </div>
        )}

        <Button
          onClick={handleDeposit}
          className="w-full bg-teal-600 hover:bg-teal-700"
          disabled={!selectedToken || !amount}
        >
          Deposit Collateral
        </Button>
      </CardContent>
    </Card>
  )
}

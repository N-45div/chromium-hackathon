"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { useState } from "react"
import { useToast } from "@/hooks/use-toast"
import { AlertTriangle } from "lucide-react"

const borrowTokens = [{ symbol: "USDC", name: "USD Coin", apy: "8.5%", available: "18750" }]

export function BorrowInterface() {
  const [selectedToken, setSelectedToken] = useState("")
  const [amount, setAmount] = useState("")
  const { toast } = useToast()

  const handleBorrow = () => {
    if (!selectedToken || !amount) {
      toast({
        title: "Error",
        description: "Please select a token and enter an amount",
        variant: "destructive",
      })
      return
    }

    toast({
      title: "Borrow Request Initiated",
      description: `Borrowing ${amount} ${selectedToken}`,
    })
  }

  const selectedTokenData = borrowTokens.find((t) => t.symbol === selectedToken)
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
              {borrowTokens.map((token) => (
                <SelectItem key={token.symbol} value={token.symbol} className="text-white hover:bg-slate-600">
                  <div className="flex items-center justify-between w-full">
                    <span>{token.name}</span>
                    <span className="text-teal-400 ml-2">{token.apy}</span>
                  </div>
                </SelectItem>
              ))}
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
              onClick={() => selectedTokenData && setAmount(selectedTokenData.available)}
            >
              MAX
            </Button>
          </div>
          {selectedTokenData && (
            <p className="text-sm text-gray-400">
              Available: ${selectedTokenData.available} {selectedToken}
            </p>
          )}
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
                <span className="text-white">{selectedTokenData?.apy}</span>
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
                  Warning: This borrow amount will significantly reduce your health factor. Consider borrowing less to
                  maintain a safer position.
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
          Borrow {selectedToken}
        </Button>
      </CardContent>
    </Card>
  )
}

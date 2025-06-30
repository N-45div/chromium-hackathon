"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Badge } from "@/components/ui/badge"
import { useState } from "react"
import { useToast } from "@/hooks/use-toast"

const activeLoans = [
  {
    token: "USDC",
    chain: "BNB Chain",
    amount: "15,420.50",
    interest: "1,234.56",
    total: "16,655.06",
    apy: "8.5%",
  },
  {
    token: "USDC",
    chain: "Avalanche",
    amount: "8,036.28",
    interest: "578.61",
    total: "8,614.89",
    apy: "7.2%",
  },
]

export function RepayLoans() {
  const [selectedLoan, setSelectedLoan] = useState("")
  const [amount, setAmount] = useState("")
  const [repayType, setRepayType] = useState("partial")
  const { toast } = useToast()

  const handleRepay = () => {
    if (!selectedLoan || !amount) {
      toast({
        title: "Error",
        description: "Please select a loan and enter an amount",
        variant: "destructive",
      })
      return
    }

    toast({
      title: "Repayment Initiated",
      description: `Repaying ${amount} ${selectedLoan}`,
    })
  }

  const selectedLoanData = activeLoans.find((l) => `${l.token}-${l.chain}` === selectedLoan)
  const earlyRepaymentSavings = amount ? (Number.parseFloat(amount.replace(",", "")) * 0.02).toFixed(2) : "0"

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white">Repay Loans</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="space-y-2">
          <Label className="text-gray-300">Active Loan</Label>
          <Select value={selectedLoan} onValueChange={setSelectedLoan}>
            <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
              <SelectValue placeholder="Select loan to repay" />
            </SelectTrigger>
            <SelectContent className="bg-slate-700 border-slate-600">
              {activeLoans.map((loan) => (
                <SelectItem
                  key={`${loan.token}-${loan.chain}`}
                  value={`${loan.token}-${loan.chain}`}
                  className="text-white hover:bg-slate-600"
                >
                  <div className="flex items-center justify-between w-full">
                    <span>
                      {loan.amount} {loan.token}
                    </span>
                    <Badge variant="outline" className="border-orange-500 text-orange-400 ml-2">
                      {loan.chain}
                    </Badge>
                  </div>
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label className="text-gray-300">Repayment Type</Label>
          <Select value={repayType} onValueChange={setRepayType}>
            <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
              <SelectValue />
            </SelectTrigger>
            <SelectContent className="bg-slate-700 border-slate-600">
              <SelectItem value="partial" className="text-white hover:bg-slate-600">
                Partial Repayment
              </SelectItem>
              <SelectItem value="full" className="text-white hover:bg-slate-600">
                Full Repayment
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
              disabled={repayType === "full"}
            />
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="absolute right-2 top-1/2 transform -translate-y-1/2 text-teal-400 hover:text-teal-300"
              onClick={() => {
                if (selectedLoanData) {
                  setAmount(repayType === "full" ? selectedLoanData.total : selectedLoanData.amount)
                }
              }}
            >
              {repayType === "full" ? "FULL" : "MAX"}
            </Button>
          </div>
          {selectedLoanData && (
            <div className="text-sm text-gray-400 space-y-1">
              <p>
                Outstanding: {selectedLoanData.amount} {selectedLoanData.token}
              </p>
              <p>
                Interest: {selectedLoanData.interest} {selectedLoanData.token}
              </p>
              <p>
                Total: {selectedLoanData.total} {selectedLoanData.token}
              </p>
            </div>
          )}
        </div>

        {selectedLoan && amount && (
          <div className="space-y-4">
            <div className="p-4 bg-slate-700/50 rounded-lg space-y-2">
              <h4 className="text-white font-medium">Interest Calculation</h4>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Current APY</span>
                <span className="text-white">{selectedLoanData?.apy}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Early Repayment Savings</span>
                <span className="text-green-400">${earlyRepaymentSavings}</span>
              </div>
            </div>

            {repayType === "full" && (
              <div className="p-4 bg-green-500/10 border border-green-500/30 rounded-lg">
                <h4 className="text-green-400 font-medium mb-2">Early Repayment Benefits</h4>
                <ul className="text-sm text-green-300 space-y-1">
                  <li>• No future interest charges</li>
                  <li>• Improved health factor</li>
                  <li>• Increased borrowing capacity</li>
                </ul>
              </div>
            )}
          </div>
        )}

        <Button
          onClick={handleRepay}
          className="w-full bg-orange-600 hover:bg-orange-700"
          disabled={!selectedLoan || (!amount && repayType === "partial")}
        >
          {repayType === "full" ? "Repay Full Loan" : "Make Partial Repayment"}
        </Button>
      </CardContent>
    </Card>
  )
}

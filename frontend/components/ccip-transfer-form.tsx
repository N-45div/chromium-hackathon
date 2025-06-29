"use client"

"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { useToast } from "@/hooks/use-toast"

export function CCIPTransferForm() {
  const [destinationChain, setDestinationChain] = useState("")
  const [token, setToken] = useState("")
  const [amount, setAmount] = useState("")
  const [recipient, setRecipient] = useState("")
  const { toast } = useToast()

  const handleSubmit = async () => {
    if (!destinationChain || !token || !amount || !recipient) {
      toast({
        title: "Error",
        description: "Please fill in all required fields",
        variant: "destructive",
      })
      return
    }

    // Clean the amount string: remove commas and ensure it's a valid number format
    const cleanedAmount = amount.replace(/,/g, '');
    if (isNaN(Number(cleanedAmount))) {
      toast({
        title: "Error",
        description: "Please enter a valid number for the amount",
        variant: "destructive",
      });
      return;
    }

    try {
      const response = await fetch("http://localhost:3001/api/svm-to-evm-transfer", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          destinationChain,
          token,
          amount: cleanedAmount, // Use the cleaned amount
          recipient,
        }),
      });

      const data = await response.json();

      if (response.ok) {
        toast({
          title: "Transfer Initiated",
          description: (
            <div>
              <p>{data.message || "SVM to EVM transfer initiated successfully."}</p>
              {data.txSignature && <p>Transaction Signature: {data.txSignature}</p>}
              {data.messageId && (
                <p>
                  Message ID: {data.messageId}{' '}
                  {data.ccipExplorerUrl && (
                    <a href={data.ccipExplorerUrl} target="_blank" rel="noopener noreferrer" className="text-blue-400 underline">
                      View on CCIP Explorer
                    </a>
                  )}
                </p>
              )}
            </div>
          ),
        });
      } else {
        toast({
          title: "Transfer Failed",
          description: data.error || "An unknown error occurred during transfer.",
          variant: "destructive",
        });
      }
    } catch (error) {
      console.error("Error during fetch:", error);
      toast({
        title: "Network Error",
        description: "Could not connect to the backend server.",
        variant: "destructive",
      });
    }
  }

  return (
    <Card className="w-full max-w-2xl bg-slate-800 border-slate-700 text-white">
      <CardHeader>
        <CardTitle className="text-2xl">Cross-Chain Transfer</CardTitle>
        <CardDescription>
          Transfer tokens from Solana to an EVM chain.
        </CardDescription>
      </CardHeader>
      <CardContent className="grid gap-6">
        <div className="grid gap-2">
          <Label htmlFor="destination-chain">Destination Chain</Label>
          <Select onValueChange={setDestinationChain}>
            <SelectTrigger
              id="destination-chain"
              className="bg-slate-700 border-slate-600"
            >
              <SelectValue placeholder="Select a chain" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="ETHEREUM_SEPOLIA">Ethereum Sepolia</SelectItem>
              <SelectItem value="BASE_SEPOLIA">Base Sepolia</SelectItem>
              <SelectItem value="ARBITRUM_SEPOLIA">Arbitrum Sepolia</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="grid gap-2">
          <Label htmlFor="token">Token</Label>
          <Input
            id="token"
            placeholder="Enter token address"
            className="bg-slate-700 border-slate-600"
            value={token}
            onChange={(e) => setToken(e.target.value)}
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="amount">Amount</Label>
          <Input
            id="amount"
            placeholder="Enter amount"
            className="bg-slate-700 border-slate-600"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="recipient">Recipient</Label>
          <Input
            id="recipient"
            placeholder="Enter recipient address"
            className="bg-slate-700 border-slate-600"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
          />
        </div>
      </CardContent>
      <CardFooter>
        <Button
          className="w-full bg-teal-600 hover:bg-teal-700"
          onClick={handleSubmit}
        >
          Transfer
        </Button>
      </CardFooter>
    </Card>
  )
}

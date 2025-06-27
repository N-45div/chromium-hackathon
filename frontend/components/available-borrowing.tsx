"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { TrendingUp, TrendingDown } from "lucide-react"
import {useState, useEffect} from 'react'
import { useToast } from "@/hooks/use-toast"
import { ethers } from 'ethers'
import BorrowManagementABI from '../../abi/BorrowManagement.json'

const BORROW_MANAGEMENT_ADDRESS = "0xd4aa953485eF4f1A916e42b9350Ab510f0920465"
const BORROW_USDC = '0x5425890298a76a5fDE71C00E1554ebb843aB41d2'
const CHAIN_IDS = {
  FUJI: 43113
}

const borrowingOptions = [
  {
    chain: "BNB Chain",
    token: "USDC",
    available: "$18,750.00",
    apy: "8.5%",
    trend: "up",
    capacity: "75%",
  },
  {
    chain: "Avalanche",
    token: "USDC",
    available: "$22,100.00",
    apy: "7.2%",
    trend: "down",
    capacity: "82%",
  },
  {
    chain: "Ethereum",
    token: "USDC",
    available: "$15,420.00",
    apy: "9.1%",
    trend: "up",
    capacity: "68%",
  },
]

export function AvailableBorrowing() {
  const [available, setAvailable] = useState('0')
  const [collateralInfo, setCollateralInfo] = useState({collateralToken: '', amount: '0'})
  const {toast} = useToast()

  useEffect(() => {
    const fetchAvailable = async () => {
      if (!window.ethereum) return
      try {
        const provider = new ethers.BrowserProvider(window.ethereum)
        const signer = await provider.getSigner()
        const userAddress = await signer.getAddress()
        const network = await provider.getNetwork()
        const chainId = Number(network.chainId)

        if (chainId !== CHAIN_IDS.FUJI) {
          toast({title: "Error", description: "Please switch to Avalanche Fuji", variant: "destructive"})
          return
        }

        const contract = new ethers.Contract(BORROW_MANAGEMENT_ADDRESS, BorrowManagementABI, provider)
        const balanceInfo = await contract.availableBorrowTokenBalance(userAddress)
        const decimals = 6 //USDC decimals
        setAvailable(ethers.formatUnits(balanceInfo.borrowedAmount, decimals))
        setCollateralInfo({
          collateralToken: balanceInfo.collateralToken,
          amount: ethers.formatUnits(balanceInfo.borrowedAmount.mul(75).div(100), decimals) //75% collateral ratio like in CollManagement.sol
        })
      } catch (error) {
        console.error("Error fetching available borrow: ", error)
        toast({title: "Error", description: "Failed to fetch available borrow amount", variant: "destructive"})
      }
 
 fetchBalance()   }
  }, [])

  return (
    <Card className="bg-slate-800/50 backdrop-blur-sm border-slate-700">
      <CardHeader>
        <CardTitle className="text-white">Available Borrowing</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex justify-between text-sm">
          <span className="text-gray-400">Borrow Token</span>
          <span className="text-white">USDC</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-gray-400">Available to Borrow</span>
          <span className="text-teal-400">{available} USDC</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-gray-400">Collateral Token</span>
          <span className="text-white">{collateralInfo.collateralToken || "None"}</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-gray-400">Collateral Value</span>
          <span className="text-white">{collateralInfo.amount} USDC</span>
        </div>
      </CardContent>
    </Card>
  )
}

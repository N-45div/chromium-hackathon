"use client"

import { createContext, useContext, useState, useEffect, type ReactNode } from "react"

interface WalletContextType {
  isConnected: boolean
  address: string | null
  connect: () => Promise<void>
  disconnect: () => void
}

const WalletContext = createContext<WalletContextType | undefined>(undefined)

export function WalletProvider({ children }: { children: ReactNode }) {
  const [isConnected, setIsConnected] = useState(false)
  const [address, setAddress] = useState<string | null>(null)

  const connect = async () => {
    try {
      // Simulate wallet connection
      const mockAddress = "0x742d35Cc6634C0532925a3b8D4C9db96590c6C87"
      setAddress(mockAddress)
      setIsConnected(true)
      localStorage.setItem("wallet_connected", "true")
      localStorage.setItem("wallet_address", mockAddress)
    } catch (error) {
      console.error("Failed to connect wallet:", error)
    }
  }

  const disconnect = () => {
    setIsConnected(false)
    setAddress(null)
    localStorage.removeItem("wallet_connected")
    localStorage.removeItem("wallet_address")
  }

  useEffect(() => {
    const connected = localStorage.getItem("wallet_connected")
    const savedAddress = localStorage.getItem("wallet_address")
    if (connected && savedAddress) {
      setIsConnected(true)
      setAddress(savedAddress)
    }
  }, [])

  return (
    <WalletContext.Provider value={{ isConnected, address, connect, disconnect }}>{children}</WalletContext.Provider>
  )
}

export function useWallet() {
  const context = useContext(WalletContext)
  if (context === undefined) {
    throw new Error("useWallet must be used within a WalletProvider")
  }
  return context
}

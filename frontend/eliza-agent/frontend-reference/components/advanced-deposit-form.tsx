"use client"

import { ethers } from "ethers"
import { createContext, useContext, useState, useEffect, type ReactNode } from "react"

interface WalletProviderInfo {
  name: string
  uuid: string
  provider: any
}

interface WalletContextType {
  isConnected: boolean
  address: string | null
  connect: () => Promise<void>
  disconnect: () => void
  availableProviders: WalletProviderInfo[]
  selectedProvider: WalletProviderInfo | null
}

const WalletContext = createContext<WalletContextType | undefined>(undefined)

export function WalletProvider({ children }: { children: ReactNode }) {
  const [isConnected, setIsConnected] = useState(false)
  const [address, setAddress] = useState<string | null>(null)
  const [availableProviders, setAvailableProviders] = useState<WalletProviderInfo[]>([])
  const [selectedProvider, setSelectedProvider] = useState<WalletProviderInfo | null>(null)

  useEffect(() => {
    // EIP-6963: Detect wallet providers
    const handleProviderDiscovery = (event: Event) => {
      const { info, provider } = (event as CustomEvent).detail
      setAvailableProviders((prev) => {
        if (!prev.some((p) => p.uuid === info.uuid)) {
          return [...prev, { name: info.name, uuid: info.uuid, provider }]
        }
        return prev
      })
    }

    window.addEventListener('eip6963:announceProvider', handleProviderDiscovery)
    window.dispatchEvent(new Event('eip6963:requestProvider'))

    return () => window.removeEventListener('eip6963:announceProvider', handleProviderDiscovery)
  }, [])

  const connect = async () => {
    if (availableProviders.length === 0) {
      alert("No wallet providers detected! Please install a wallet like MetaMask or Coinbase Wallet.")
      return
    }

    try {
      // Prompt user to select a wallet
      const providerOptions = availableProviders.map((p) => p.name).join(', ')
      const selectedProviderName = prompt(`Select a wallet: ${providerOptions}`)
      const providerInfo = availableProviders.find((p) => p.name === selectedProviderName)

      if (!providerInfo) {
        alert("Invalid wallet selection!")
        return
      }

      const provider = new ethers.BrowserProvider(providerInfo.provider)
      const accounts = await provider.send("eth_requestAccounts", [])
      const userAddress = accounts[0]

      setSelectedProvider(providerInfo)
      setAddress(userAddress)
      setIsConnected(true)
      localStorage.setItem("wallet_connected", "true")
      localStorage.setItem("wallet_address", userAddress)
      localStorage.setItem("wallet_provider", providerInfo.uuid)
    } catch (error) {
      console.error("Failed to connect wallet:", error)
      alert("Failed to connect wallet. Please try again.")
    }
  }

  const disconnect = () => {
    setIsConnected(false)
    setAddress(null)
    setSelectedProvider(null)
    localStorage.removeItem("wallet_connected")
    localStorage.removeItem("wallet_address")
    localStorage.removeItem("wallet_provider")
  }

  useEffect(() => {
    const connected = localStorage.getItem("wallet_connected")
    const savedAddress = localStorage.getItem("wallet_address")
    const savedProviderUuid = localStorage.getItem("wallet_provider")

    if (connected && savedAddress && savedProviderUuid) {
      const savedProvider = availableProviders.find((p) => p.uuid === savedProviderUuid)
      if (savedProvider) {
        setIsConnected(true)
        setAddress(savedAddress)
        setSelectedProvider(savedProvider)
      }
    }
  }, [availableProviders])

  return (
    <WalletContext.Provider
      value={{ isConnected, address, connect, disconnect, availableProviders, selectedProvider }}
    >
      {children}
    </WalletContext.Provider>
  )
}

export function useWallet() {
  const context = useContext(WalletContext)
  if (context === undefined) {
    throw new Error("useWallet must be used within a WalletProvider")
  }
  return context
}
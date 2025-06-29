import * as React from "react"
import { ToastProps } from "@/components/ui/toast"

const TOAST_LIMIT = 1
const TOAST_REMOVE_DELAY = 1000000

type ToasterToast = ToastProps & { id: string }

const actionTypes = {
  ADD_TOAST: "ADD_TOAST",
  UPDATE_TOAST: "UPDATE_TOAST",
  DISMISS_TOAST: "DISMISS_TOAST",
  REMOVE_TOAST: "REMOVE_TOAST",
} as const

type Action = 
  | { type: typeof actionTypes.ADD_TOAST; toast: ToasterToast }
  | { type: typeof actionTypes.UPDATE_TOAST; toast: Partial<ToasterToast> }
  | { type: typeof actionTypes.DISMISS_TOAST; toastId?: ToasterToast["id"] }
  | { type: typeof actionTypes.REMOVE_TOAST; toastId?: ToasterToast["id"] }

interface State { 
  toasts: ToasterToast[]
}

const reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case actionTypes.ADD_TOAST:
      return {
        ...state,
        toasts: [action.toast, ...state.toasts].slice(0, TOAST_LIMIT),
      }

    case actionTypes.UPDATE_TOAST:
      return {
        ...state,
        toasts: state.toasts.map((t) =>
          t.id === action.toast.id ? { ...t, ...action.toast } : t
        ),
      }

    case actionTypes.DISMISS_TOAST:
      const { toastId } = action

      // ! Side effects ! - This is not beautiful, but it's the best way to
      // get the toast to animate out and then remove itself from the DOM.
      return {
        ...state,
        toasts: state.toasts.map((t) =>
          t.id === toastId || toastId === undefined
            ? { ...t, open: false }
            : t
        ),
      }
    case actionTypes.REMOVE_TOAST:
      if (action.toastId === undefined) {
        return {
          ...state,
          toasts: [],
        }
      }
      return {
        ...state,
        toasts: state.toasts.toasts.filter((t) => t.id !== action.toastId),
      }
  }
}

function generateId() {
  return Math.random().toString(36).substring(2, 9)
}

function useToast() {
  const [state, dispatch] = React.useReducer(reducer, { toasts: [] })
  const [pausedAt, setPausedAt] = React.useState<number | undefined>(undefined)

  const timerRef = React.useRef<ReturnType<typeof setTimeout>>()

  const removeToast = React.useCallback(
    (toastId?: string) => dispatch({ type: actionTypes.REMOVE_TOAST, toastId }),
    [dispatch]
  )

  React.useEffect(() => {
    if (pausedAt) {
      return
    }

    if (timerRef.current) {
      clearTimeout(timerRef.current)
    }

    if (state.toasts.length && state.toasts[0]?.open === false) {
      timerRef.current = setTimeout(() => {
        removeToast(state.toasts[0].id)
      }, TOAST_REMOVE_DELAY)
    }
  }, [state.toasts, pausedAt, removeToast])

  const addToast = React.useCallback(
    (toast: ToasterToast) => {
      dispatch({ type: actionTypes.ADD_TOAST, toast })
    },
    [dispatch]
  )

  const toast = React.useCallback(
    (props: ToastProps) => {
      const id = generateId()

      const update = (props: Partial<ToasterToast>) =>
        dispatch({ type: actionTypes.UPDATE_TOAST, toast: { ...props, id } })
      const dismiss = () => dispatch({ type: actionTypes.DISMISS_TOAST, toastId: id })

      addToast({ ...props, id, open: true, update, dismiss })

      return { id, update, dismiss }
    },
    [addToast]
  )

  return { 
    toasts: state.toasts,
    toast,
    dismiss: React.useCallback(
      (toastId?: string) => dispatch({ type: actionTypes.DISMISS_TOAST, toastId }),
      [dispatch]
    ),
  }
}

export { useToast, reducer as toastReducer }
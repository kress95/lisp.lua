
;;;;
;;;; global helpers
;;;;

;; blocks evil global get/set
(setmetatable _G
  {table
    (kv __index
        (function [_ k]
          (error (.. "variable " k " is not declared") 2))
     (kv __newindex
         (function [_ k v]
           (error (.. "declaring global " k " to " (tostring v)) 2))))})

;;; throws a previously catched error
(= (local error2)
   (function [msg lvl]
    (if [(== (type msg) "string")
         (= msg ((. string gsub) msg ".-%.lua%:%d+%:%s" ""))])
    (= lvl (+ (or lvl 1) 1))
    (error msg lvl)))

;;;;
;;;; compiler types
;;;;

;;;; leaf type
(= (local leaf)
   {table (kv __index {table})})
(do
  ;;;;
  ;;;; data stores
  ;;;;

  ;; stores leaf's content
  (= (local content-store)
     (setmetatable {table} {table (kv __mode "k")}))

  ;; stores leaf's atomicity
  (= (local atom-store)
     (setmetatable {table} {table (kv __mode "k")}))

  ;; stores leaf's debug information
  (= (local debug-store)
     (setmetatable {table} {table (kv __mode "k")}))

  ;;;;
  ;;;; constructors
  ;;;;

  ;;; leaf/create-value
  (= (. leaf create-value)
     (function [value debug]
      (= (local self)
         (setmetatable {table} leaf))
      (= (at content-store self) value)
      (= (at debug-store self) debug)
      (return self)))

  ;;; leaf/create-atom
  (= (. leaf create-atom)
     (function [value debug]
      (= (local self)
         (setmetatable {table} leaf))
      (= (at content-store self) value)
      (= (at atom-store self) true)
      (= (at debug-store self) debug)
      (return self)))

  ;;;
  ;;; query
  ;;;

  ;;; leaf.is-leaf
  (= (. leaf is-leaf)
     (function [maybe-self]
      (return (== (getmetatable maybe-self) leaf))))

  ;;; leaf.is-atom
  (= (. leaf is-atom)
     (function [self]
      (return (== (at atom-store self) true))))

  ;;; leaf.content
  (= (. leaf content)
     (function [self]
      (if [((. leaf is-leaf) self)
           (return (at content-store self))]
          [else (return self)])))

  ;;; self.__tostring
  (= (. leaf __tostring)
    (function [self]
      (= (local content) (at content-store self))
      (= (local data) (pcall tostring content))
      (= (local ok) (at data 1))
      (= (local msg) (at data 1))
      (if [ok (return msg)]
          [(~= (at msg 1) nil) (error2 (at msg 1) 2)]
          [else (error "" 2)]))))

;;;; node type
;(= (local node) {table})
;(do) ;TODO

;;;; stream type
;(= (local stream) {table})
;(do) ;TODO

;;;;
;;;; compiler functions
;;;;

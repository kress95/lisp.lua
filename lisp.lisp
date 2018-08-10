
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
      (return (at content-store self))))

  ;;;;
  ;;;; metatable events
  ;;;;

  ;;;; helpers

  ;;; wrapped operators
  (= (local op-get) (function [self k] (return (at self k))))
  (= (local op-set) (function [self k v] (= (at self k) v)))
  (= (local op-len) (function [self] (return (# self))))
  (= (local op-unm) (function [self] (return (- self))))
  (= (local op-add) (function [self a b] (return (+ a b))))
  (= (local op-sub) (function [self a b] (return (- a b))))
  (= (local op-mul) (function [self a b] (return (* a b))))
  (= (local op-div) (function [self a b] (return (/ a b))))
  (= (local op-mod) (function [self a b] (return (% a b))))
  (= (local op-pow) (function [self a b] (return (^ a b))))
  (= (local op-concat) (function [self a b] (return (.. a b))))
  (= (local op-eq) (function [self a b] (return (== a b))))
  (= (local op-lt) (function [self a b] (return (<= a b))))
  (= (local op-le) (function [self a b] (return (>= a b))))

  ;;; returns a metamethod proxy for 1 param (self)
  (= (local metamethod-1)
     (function [op]
      (return (function [self]
               (= (local content) (at content-store self))
               (= (local data) {table (pcall op content)})
               (= (local ok) (at data 1))
               (= (local msg) {at data 2})
               (if [ok (return ((. leaf create-value) msg))]
                   [(~= msg nil) (error2 msg 2)]
                   [else (error "" 2)])))))

  ;;; returns a metamethod proxy for 2 params (self/other)
  (= (local metamethod-2)
     (function [op]
      (return (function [self other]
               (if [((. leaf is-leaf) other) (= other (at content-store other))])
               (= (local content) (at content-store self))
               (= (local data) {table (pcall op content)})
               (= (local ok) (at data 1))
               (= (local msg) {at data 2})
               (if [ok (return ((. leaf create-value) msg))]
                   [(~= msg nil) (error2 msg 2)]
                   [else (error "" 2)]))))))

;;;; metamethod proxies

;;; __index proxy
(= (. leaf __index)
   (function [self k]
    (if [((. leaf is-leaf) k) (= k (at content-store k))])
    (= (local content) (at content-store self))
    (= (local data) {table (pcall op-get content k)})
    (= (local ok) (at data 1))
    (= (local msg) {table (select 2 (unpack data))})
    (if [ok
          (= (local len) (# msg))
          (for [(i 1) len]
               (= (at msg i) ((. leaf create-value) (at msg i))))
          (return (unpack msg))]
        [(~= (at msg 1) nil) (error2 (at msg 1) 2)]
        [else (error "" 2)])))

  ;;; __newindex proxy
  (= (. leaf __newindex)
     (function [self k v]
      (if [((. leaf is-leaf) k) (= k (at content-store k))])
      (if [((. leaf is-leaf) v) (= v (at content-store v))])
      (= (local content) (at content-store self))
      (= (local data) {table (pcall op-set content k v)})
      (= (local ok) (at data 1))
      (= (local msg) {at data 2})
      (if [ok (return)])
      (if [(~= msg nil) (error2 msg 2)]
          [else (error "" 2)])))

  ; ;;; __len
  ; (= (. leaf __len)
  ;    (function [self]
  ;     (= (local content) (at content-store self))
  ;     (= (local data) {table (pcall op-len content)})
  ;     (= (local ok) (at data 1))
  ;     (= (local msg) {at data 2})
  ;     (if [ok (return msg)]
  ;         [(~= msg nil) (error2 msg 2)]
  ;         [else (error "" 2)])))

  ; ;;; __unm
  ; (= (. leaf __unm)
  ;    (function [self]
  ;     (= (local content) (at content-store self))
  ;     (= (local data) {table (pcall op-unm content)})
  ;     (= (local ok) (at data 1))
  ;     (= (local msg) {at data 2})
  ;     (if [ok (return msg)]
  ;         [(~= msg nil) (error2 msg 2)]
  ;         [else (error "" 2)])))

  ; ;;; __pairs
  ; (= (. leaf __pairs)
  ;    (function [self]
  ;     (= (local content) (at content-store self))
  ;     (= (local data) {table (pcall pairs content)})
  ;     (= (local ok) (at data 1))
  ;     (= (local msg) {at data 2})
  ;     (if [ok (return msg)]
  ;         [(~= msg nil) (error2 msg 2)]
  ;         [else (error "" 2)])))
  ;

  ;  function leaf.__pairs(self) return pairs(rawget(self, 'g_g_raw')) end
  ;  function leaf.__ipairs(self) return ipairs(rawget(self, 'g_g_raw')) end

;;;; node type
;(= (local node) {table})
;(do) ;TODO

;;;; stream type
;(= (local stream) {table})
;(do) ;TODO

;;;;
;;;; compiler functions
;;;;

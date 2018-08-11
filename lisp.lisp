
;;;;
;;;; global helpers
;;;;

(local puts)
(do
  (= (local ok inspect) (pcall require "inspect"))
  (if [ok
       (= puts
          (function [item ...]
            (print (inspect item ...))
            (return item)))]
      [else
       (= puts
          (function [item]
            (print item)
            (return item)))]))

;; blocks evil global get/set
(setmetatable _G
  {table
    (kv __index
        (function [_ k]
          (error (.. "variable " k " is not declared") 2))
     (kv __newindex
         (function [_ k v]
           (error (.. "declaring global " k " to " (tostring v)) 2))))})

;;;; functions

;;; throws a previously catched error
(= (local error2)
   (function [msg lvl]
    (if [(== (type msg) "string")
         (= msg (string-gsub msg ".-%.lua%:%d+%:%s" ""))])
    (= lvl (+ (or lvl 1) 1))
    (error msg lvl)))

;;; localized functions
(= (local string-gsub) (. string gsub))
(= (local string-sub) (. string sub))
(= (local table-concat) (. table concat))
(= (local debug-getinfo) (. debug getinfo))

;;;;
;;;; compiler types
;;;;

;;;; srcmap type
(local
  srcmap-create
  is-srcmap
  srcmap-source
  srcmap-line
  srcmap-column)
(do
  (= (local srcmap) {table})

  ;;;;
  ;;;; build
  ;;;;

  ;;; srcmap-create
  (= srcmap-create
     (function [source line column]
      (return
        (setmetatable
          {table (kv source source)
                 (kv line line)
                 (kv column column)}
          srcmap))))

  ;;;;
  ;;;; query
  ;;;;

  ;;; is-srcmap
  (= is-srcmap
     (function [maybe-self] (return (== (getmetatable maybe-self) srcmap))))

  ;;; srcmap-source
  (= srcmap-source
     (function [self] (return (at self source))))

  ;;; srcmap-line
  (= srcmap-line
     (function [self] (return (at self line))))

  ;;; srcmap-column
  (= srcmap-column
     (function [self] (return (at self column)))))

;;;; list type
(local
  list-create-empty
  list-create-with
  list-cons
  list-reverse
  is-list
  list-head
  list-tail
  list-split
  list-to-table
  list-unpack)
(do
  (= (local list) {table})

  ;;;;
  ;;;; build
  ;;;;

  ;;; list-create-empty
  (= list-create-empty
     (function [] (return (setmetatable {table} list))))

  ;;; list-create-with
  (= list-create-with
     (function [this ...]
      (if [(~= this nil)
           (return (setmetatable {table this (list-create-with ...)} list))]
          [else (return (setmetatable {table this} list))])))

  ;;; list-cons
  (= list-cons
     (function [item other] (return (setmetatable {table item other} list))))

  ;;; list-reverse
  (= list-set-reverse
     (function [self]
      (= (local other) (list-create-empty))
      (while (at self 2)
        (= other (list-cons (at self 1) other))
        (= self (at self 2)))
      (return other)))

  ;;;;
  ;;;; query
  ;;;;

  ;;; is-list
  (= is-list
     (function [maybe-self] (return (== (getmetatable maybe-self) list))))

  ;;; list-head
  (= list-head
     (function [self] (return (at self 1))))

  ;;; list-tail
  (= list-tail
     (function [self] (return (at self 2))))

  ;;; list-split
  (= list-split
     (function [self at]
      (= (local left idx right) {table} 0 self)
      (for-in [tail head] [(pairs self)]
        (if [(> idx at) (break)])
        (= idx (+ idx 1))
        (= (at left idx) head)
        (= right tail))
      (return (list-create-with (unpack left)) right)))

  ;;; list-to-table
  (= list-to-table
     (function [self]
      (= (local arr idx) {table} 0)
      (while (at self 2)
        (= idx (+ idx 1))
        (= (at arr idx) (at self 1))
        (= self (at self 2)))
      (return arr)))

  ;;; list/unpack
  (= list-unpack
     (function [self] (return (unpack (list-to-table self)))))

  ;;; list/__len
  (= (. list __len)
     (function [self]
      (= (local len) 0)
      (while (at self 2)
        (= len (+ len 1))
        (= self (at self 2)))
      (return len)))

  ;;; list/__pairs
  (= (local next)
     (function [_ self] (if [self (return (at self 2) (at self 1))])))
  (= (. list __pairs)
     (function [self] (return next self self)))

  ;;; list/__tostring
  (= (. list __tostring)
     (function [self]
       (= (local out idx) {table "("} 1)
       (for-in [tail head] [(pairs self)]
        (= idx (+ idx 1))
        (= (at out idx) (tostring head))
        (if [(at tail 2)
             (= idx (+ idx 1))
             (= (at out idx) " ")]))
      (= (at out (+ idx 1)) ")")
      (return (table-concat out "")))))

;;;; box type
(local
  box-create-value
  box-create-atom
  is-box
  box-is-atom
  box-content
  box-srcmap)
(do
  (= (local box) {table})

  ;;;;
  ;;;; data stores
  ;;;;

  ;; stores box's content
  (= (local content-store)
     (setmetatable {table} {table (kv __mode "k")}))

  ;; stores box's atomicity
  (= (local atom-store)
     (setmetatable {table} {table (kv __mode "k")}))

  ;; stores box's srcmap information
  (= (local srcmap-store)
     (setmetatable {table} {table (kv __mode "k")}))

  ;;;;
  ;;;; build
  ;;;;

  ;;; box-create-value
  (= box-create-value
     (function [value srcmap]
      (= (local self) (setmetatable {table} box))
      (= (at content-store self) value)
      (= (at srcmap-store self) srcmap)
      (return self)))

  ;;; box-create-atom
  (= box-create-atom
     (function [value srcmap]
      (= (local self) (setmetatable {table} box))
      (= (at content-store self) value)
      (= (at atom-store self) true)
      (= (at srcmap-store self) srcmap)
      (return self)))

  ;;;
  ;;; query
  ;;;

  ;;; is-box
  (= is-box
     (function [maybe-self] (return (== (getmetatable maybe-self) box))))

  ;;; box-is-atom
  (= box-is-atom
     (function [self] (return (== (at atom-store self) true))))

  ;;; box-content
  (= box-content
     (function [self] (return (at content-store self))))

  ;;; box-srcmap
  (= box-srcmap
     (function [self] (return (at srcmap-store self))))

  ;;; box-__tostring
  (= (. box __tostring)
     (function [self]
      (= (local content) (at content-store self))
      (= (local data) (pcall tostring content))
      (= (local ok) (at data 1))
      (= (local msg) (at data 1))
      (if [ok (return msg)]
          [(~= (at msg 1) nil) (error2 (at msg 1) 2)]
          [else (error "" 2)]))))

;;;; any type
(local any-content
       any-srcmap)
(do
  ;;; any-content
  (= any-content
     (function [any]
      (if [(is-box any) (return (box-content any))]
          [else (return any)]))))

;;;; form type
(local form-create
       form-map-open
       form-map-close
       form-map-list
       is-form
       form-open
       form-close
       form-list)
(do
  (= (local form) {table})

  ;;;;
  ;;;; build
  ;;;;

  ;;; form-create
  (= form-create
     (function [open]
      (local list (list-create-empty))
      (return (setmetatable {table (kv open open)
                                   (kv close open)
                                   (kv list list)}
                            form))))

  ;;;;
  ;;;; map
  ;;;;

  ;;; form-map-open
  (= form-map-open
     (function [self open]
      (return (setmetatable {table (kv open open)
                                   (kv close (. self close))
                                   (kv list (. self list))}
                            form))))

  ;;; form-map-close
  (= form-open
     (function [self close]
      (return (setmetatable {table (kv open (. self open))
                                   (kv close close)
                                   (kv list (. self list))}
                            form))))

  ;;; form-map-list
  (= form-map-list
     (function [self list]
      (return (setmetatable {table (kv open (. self open))
                                   (kv close (. self close))
                                   (kv list list)}
                            form))))

  ;;;;
  ;;;; query
  ;;;;

  ;;; is-form
  (= is-form
     (function [maybe-self]
      (return (== (getmetatable maybe-self) form))))

  ;;; form-open
  (= form-open
     (function [self] (return (at self open))))

  ;;; form-close
  (= form-close
     (function [self] (return (at self close))))

  ;;; form-list
  (= form-list
     (function [self] (return (at self list))))

  ;;; form/__len
  (= (. form __len)
     (function [self] (return (# (. self list)))))

  ;;; form/__pairs
  (= (. form __pairs)
     (function [self] (return (pairs (. self list)))))

  ;;; form/__tostring
  (= (. form __tostring)
     (function [self] (return (tostring (. self list))))))

(puts (any-content 1))
;;;; stream type
;(= (local stream) {table})
;(do) ;TODO

;;;;
;;;; compiler functions
;;;;

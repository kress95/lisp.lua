
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
(= (local string-byte) (. string byte))
(= (local table-concat) (. table concat))
(= (local debug-getinfo) (. debug getinfo))
(= (local io-open) (. io open))
(= (local io-read) (. io read))
(= (local io-close) (. io close))

;;;;
;;;; compiler types
;;;;

;;;; immutable srcmap type
(local srcmap-create
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

;;;; immutable list type
(local list-create-empty
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

;;;; immutable box type
(local box-create-value
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

;;;; immutable form type
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

;;;; mutable stream type
(local stream-create
       stream-from-string
       stream-from-file
       is-stream
       stream-move
       stream-next)
(do
  (= (local stream) {table})

  ;;;;
  ;;;; build
  ;;;;

  ;;;; helpers

  (= (local from-file)
     (function [path]
      (= (local file) (assert (io-open path "r")))
      (= (local closed) false)
      (return
        (function []
          (if [closed (return)])
          (= (local char) (io-read file 1))
          (if [char (return (string-byte char 1))]
              [else
               (io-close file)
               (= closed true)]))
        file)))

  (= (local from-string)
     (function [str]
      (= (local idx) 0)
      (= (local len) #str)
      (return
        (function []
          (if [(>= idx len) (return)])
          (= idx (+ idx 1))
          (return (string-byte str idx))))))

  ;;;; implementation

  ;;; stream-create
  (= stream-create
     (function [get-char source]
        (return (setmetatable {table (kv get-char get-char)
                                     (kv source source)
                                     (kv index 0)
                                     (kv cache {table})
                                     (kv cache-length 0)}
                              stream))))

  ;;; stream-from-file
  (= stream-from-file
     (function [path]
      (= (local get-char file) (from-file path))
      (return (stream-create get-char path) file)))

  ;;; stream-from-string
  (= stream-from-string
     (function [str source]
      (return (stream-create (from-string str) (or source "in-memory")))))

  ;;;;
  ;;;; query
  ;;;;

  ;;;; helpers

  ;;; returns a new srcmap for the new character
  (= (local get-srcmap)
     (function [self char]
      (= (local srcmap) (. (at (. self cache) (. self length)) srcmap))
      (= (local line column) (or (. srcmap line) 0) (or (. srcmap column) 0))
      (if [(== char 10)
           (= line (+ line 1))
           (= column 1)]
          [(~= char 13)
           (= column (+ column 1))])
      (return (srcmap-create (. self source) line column))))

  ;;; push following character to cache
  (= (local push-char)
     (function [self char]
      (= (local length) (+ (. self cache-length) 1))
      (= (local srcmap) (get-srcmap self char))
      (= (local cached) {table (kv char char) (kv srcmap srcmap)})
      (= (at (. self cache) length) cached)
      (= (. self cache-length) length)
      (= (. self index) length)
      (return char srcmap)))

  ;;;; implementation

  ;;; is-stream
  (= is-stream
     (function [maybe-self]
      (return (== (getmetatable maybe-self) stream))))

  ;;; stream-move
  (= stream-move
     (function [self offset]
      (= (local index) (+ (. self index) offset))
      (if [(< index 0) (= index 0)]
          [(> index length)
           (= (local diff) (- index length))
           (for [(i 1) diff] (stream-next self))])
      (return self)))

  ;;; stream-next
  (= stream-next
     (function [self]
      (= (local index) (. self index))
      (if [(< index (. self cache-length))
           (= index (+ index 1))
           (= (. self index) index)
           (= (local cached) (at (. self cache) index))
           (return (. cached char) (. cached srcmap))]
          [else
           (= (local char) ((. self get-char)))
           (if [char (return (push-char self char))])])))

  ;;; stream/__pairs
  (= (. stream __pairs)
     (function [self]
      (return stream-next self))))

;;;; any-content function
(= (local any-content)
   (function [any]
    (if [(is-box any) (return (box-content any))]
        [else (return any)])))

;;;;
;;;; compiler functions
;;;;

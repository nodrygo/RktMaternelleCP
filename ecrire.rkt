#lang racket
(require racket/system)
(require racket/gui/base)
(require racket/draw)
(require racket/stream)
; espeak -vfr+m2 -g 11  -p 55  -s 60 "écrit le mot chien avec un C un H un I  un E un N "
; espeak -vfr+f1 -g 11  -p 55 -s 60  "écrit le chiffre 45 avec un 4 et un 5 "
; non un C   ; c'est bien    ; bravo
; maintenant un H
; decoupe mot en lettre ; sequence de lettre
; boutton nouveau mot , ré-ecouter
; lire les mots dans un fichier texte

(define wordslist (file->list "words.txt" ))
(define selection '("" "appuie sur la touche espace pour commencer " #f))
(define currentword "appuie sur la touche espace pour commencer" )
(define currentpos 0 )
(define blue-brush (new brush% [color "blue"]))
(define blue-pen (make-pen #:color "blue"))
(define green-pen (make-pen #:color "green"))
(define font (make-font #:size 55  #:weight 'ultraheavy #:family 'decorative))
(define baseimg (make-bitmap 250 250))
(define destimg (make-bitmap 250 250))
(define bptimg (make-bitmap 100 100))
(define bdc (send destimg make-dc))
;(define bptdc (send bptimg make-dc))
(define endtxt "")
(define help #f)
(define err #f)
(define playing #f)
(define bpoints 0)
(define proc #f)
;(define cout  (open-output-file "cout" #:exists 'replace))
;(define cerr  (open-output-file "cerr" #:exists 'replace ))
(define progpath (find-executable-path "espeak"))

(define (runspeak msg)
    (define-values (s stdout stdin stderr) (subprocess #f #f #f 'new progpath "-vfr+m1" "-p 60" "-s 110" msg )) 
    (set! proc s ))

(define (killspeak)
  (when proc (subprocess-kill proc #t))
)

(runspeak "choisi un mot avec la touche espace" )

; load image and normalize scale in destimg
(send bptimg  load-file "Bons_points.jpg")

(define (loadimg name)
  (when (file-exists? name)
    (println name)
       (send baseimg  load-file name)
       (let [
             (imgh (send baseimg get-height))
             (imgw (send baseimg get-width))
            ]
            (send bdc draw-bitmap-section-smooth baseimg 0 0 250 250 0 0 imgw imgh)))
)

; handle event 
(define (handle-ev ev)
        (let [(key (send ev  get-key-code))
             ]
          (send ev get-key-code)
          (handle-key key))
)

; handle keys 
(define (handle-key key)
    (cond 
         ((eq? key 'escape)(exit 0))
         ((eq? key #\space) (newword)(send canvas on-paint) )
         (else (addkey key))
    )
)

; draw word on canvas 
(define (draw-word word dc px py)
  (let-values ([( w h d v)  (send dc get-text-extent (car selection) font )  ])
    (send dc set-text-foreground "Snow")(send dc set-text-mode 'transparent)
    (send dc draw-text word  (+ w px 10) py )
    (send dc set-text-foreground "Blue")(send dc set-text-mode 'transparent)
    (send dc draw-text (car selection)   0 py )
    (unless (>= 0 currentpos )(send dc draw-text (substring word 0  currentpos) (+ w px 10)  py ))
  ))

; paint handle
(define (do-paint canvas dc)
    (let* [
         (canvasw (send canvas get-width))
         (canvash (send canvas get-height))
         (bptw 220)
         (bpth 239)
         (bptposx (- canvasw (+ bptw 5)))
         (bptposy 5)
         (px 50)
         (bptxt  (format "~a" bpoints))
         ;(py (/(send canvas get-height) 2))
         (py 400)
        ]
  (send dc clear)	 	 	 
  (send dc draw-bitmap destimg 	10 10 )
  (send dc draw-bitmap bptimg   bptposx bptposy)
  (send dc set-font font) 
  (send dc set-pen blue-pen)
  (draw-word currentword dc px (- py 100))
  (draw-word (string-upcase currentword) dc px (+ py 5))
  (send dc set-text-foreground "Red")
  ; set text bonpoints pos
  (let-values ([(tw th td tv)  (send dc get-text-extent bptxt font )  ])
  (send dc draw-text bptxt  (-(+ bptposx(/ bptw 2) )(/ tw 2)) (-(+ bptposy (/ bpth 2))(/ th 2))))     
  
  (if err
     (send dc set-text-foreground "Red")
     (send dc set-text-foreground "Green")) 
  (send dc draw-text endtxt   10 (+ py 100) )
  
 (unless playing
   (send dc set-text-foreground "Green")
   (send dc draw-text "Appuie sur ESPACE pour un nouveau mot  "  0 (+ py 200) )
)))
; define windows
(define myframe% (class frame%
                 (define/override (on-subwindow-char target ev )(handle-ev ev))
                 (super-new)))
(define mainwin (new myframe% [label "Ecris un mot"][width 600 ][height 500])) 
(define canvas (new canvas%	[parent mainwin]
                                [paint-callback do-paint]))

; display window in full screen 
(send mainwin  fullscreen #t)
(send mainwin show #t)

;change the current word
(define (newword)
  (killspeak)
  (set! playing #t)
  (set! currentpos 0)
  (set! endtxt "")
  (set! err #f)
  (set! selection (list-ref wordslist  (random 0 (- (length wordslist ) 1 ))))
  (set! currentword (list-ref selection 1  ))
  ; load img
  (loadimg   (build-path  "img" (list-ref selection 2 )))
  (send canvas on-paint)
  (send canvas  refresh-now)
  (let [(speech   (format "\"écrit ~a ~a avec un ~a \" "
                                        (list-ref selection 0 ) currentword (string-ref currentword 0) ))
       ]
    (runspeak  speech)
  )    
)

(define (addkey k)
  (unless (symbol? k )
         (when (char-alphabetic? k)
           (killspeak)
           (set! endtxt "")
           (if (eq? k (string-ref currentword  currentpos))
               (begin 
                      (set! currentpos (+ 1 currentpos))
                      (send canvas on-paint)
                      (when  (< currentpos (string-length currentword))
                        (runspeak   (format "\"un ~a \" " (string-ref currentword  currentpos)))
                      )) 
               (begin
                      (set! err #t)
                      (set! endtxt (format "non il faut un ~a " (string-ref currentword   currentpos)))                 
                      (send canvas on-paint)
                      (play-sound "Pew.wav" #f)
                      (runspeak (format "\"non un  ~a \" " (string-ref currentword   currentpos)))
                     
           ))
           
           (when (>=  currentpos (string-length currentword))
             (set! playing #f)
             (if err
                   (set! endtxt "erreur dommage")
                  (begin
                   (set! endtxt "Super tu gagnes un bon point")
                   (set! bpoints (+ 1 bpoints))))
                   (send canvas on-paint)
             (runspeak  endtxt)
             (send canvas on-paint)
             )))
)
; start with new word 


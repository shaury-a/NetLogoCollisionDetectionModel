globals [

  colors-set ;list of colors based on number specified by user

  collision-precision ; Determines how accurate the location of collisions will be

  ; It tells how much to round the angles when bouncing off the obstacle.
  angle-precision

  speed ; All agents have the same speed

  ; new-heading stores the agent's heading(direction) after collision until after all collisions have occurred.
  new-heading

  ; Used to track which agent or obstacle is being dragged
  target-object-or-obstacle
  set-target-value
  get-target-value
  target-value
]

breed [ obstacles obstacle ]
breed [ objects object ]


to setup [ obstacle-placement object-placement ]
  clear-all

  set-default-shape obstacles "circle-with-border"

  ; Creating obstacles so that it's completely inside the world
  create-obstacles num-obstacles [
    set color grey - 2
    ; Fixing size of obstacles
    set size max list 1 (0.10 * min list world-width world-height)
    ;randomly place the obstacle
    run obstacle-placement
  ]

  ;Creating objects of different shape, color is chosen by user
  create-objects num-objects [
    set shape one-of shapes
    ;choose object colors from 5-11
    set colors-set n-of object-color [5 15 25 35 45 55 65 75 85 95 105]
    ;randomly place the object
    run object-placement
  ]

  ;Collisions will be within speed / (2 ^ 64) of correct position
  set collision-precision 64
  ; Rounding of to 1000th of a degree
  set angle-precision 1000
  set speed 0.05

  reset-dragging

  reset-ticks
end

to setup-random
  setup [->
    ; Place obstacles randomly so that they're completely inside the world
    place-randomly-inside-world
  ] [->
    ; Place the object inside the world such that no overlap is there with any obstacles.
    place-randomly-inside-world
    ; keep moving the objects while checking for overlap, until there is none
    while [ any? obstacles with [ overlap myself > 0 ] ] [
      place-randomly-inside-world
    ]
  ]
end

to go
  repeat 5 [
    ask objects [
      set pen-mode ifelse-value trace-path? [ "down" ] [ "up" ]
      fd speed

      set new-heading heading

      ; Colliding with floor or ceiling
      if colliding-with-floor-or-ceiling? [
        correct-collision-position [-> colliding-with-floor-or-ceiling?]
        set new-heading 180 - new-heading
      ]

      ;Colliding with walls
      if colliding-with-walls? [
        correct-collision-position [-> colliding-with-walls?]
        set new-heading 360 - new-heading
      ]

      ;Colliding with obstacles
      foreach-obstacle obstacles [ an-obstacle ->
        if colliding-with? an-obstacle [
          bounce-off an-obstacle
        ]
      ]

      ; Colliding with other objects within radius meeting-radius
      ask objects [
        if any? other objects in-radius meeting-radius [
          bounce-off one-of other objects in-radius meeting-radius
        ]
      ]

      set heading new-heading
      pen-up
    ]
  ]
  tick
end

;Using agentset for obstacles to loop through them
to foreach-obstacle [ agentset command ]
  foreach [ self ] of  agentset [ agent ->
    (run command agent)
  ]
end



;Using binary search technique to get as close to the position of collision as possible
to correct-collision-position [ colliding? ]
  refine-collision-position colliding? speed collision-precision
end

to refine-collision-position [ colliding? dist n ]
  ifelse runresult colliding? [
    bk dist
  ][
    fd dist
  ]
  if n > 0 [
    refine-collision-position colliding? (dist / 2) (n - 1)
  ]
end

; Determine whether object is colliding with floor or ceiling
to-report colliding-with-floor-or-ceiling?
  report (dy > 0 and ycor > max-pycor) or (dy < 0 and ycor < min-pycor)
end

; Determine whether object is colliding with the walls
to-report colliding-with-walls?
  report (dx > 0 and xcor > max-pxcor) or (dx < 0 and xcor < min-pxcor)
end

; Determine whether object is colliding with obstacles or other objects
to-report colliding-with? [ an-obstacle ]
  let h abs ((heading - towards an-obstacle + 180) mod 360 - 180)
  report h < 90 and overlap an-obstacle > 0
end

; Modifies the ball's new-heading due to bouncing off the respective obstacle or other objects.
to bounce-off [ an-obstacle-or-object ]
  correct-collision-position [-> colliding-with? an-obstacle-or-object ]

  let d-x sin new-heading
  let d-y cos new-heading

  ; vx_obstacle_object and vy_obstacle_object are the respective components of the vector pointing from the obstacle to the object.
  let vx_obstacle_object xcor - [ xcor ] of an-obstacle-or-object
  let vy_obstacle_object ycor - [ ycor ] of an-obstacle-or-object

  ;Calculating new new-dx and new-dy
  let v-dot-vx_vy vx_obstacle_object * dx + vy_obstacle_object * dy
  let new-dx d-x - 2 * v-dot-vx_vy * vx_obstacle_object / (vx_obstacle_object * vx_obstacle_object + vy_obstacle_object * vy_obstacle_object)
  let new-dy d-y - 2 * v-dot-vx_vy * vy_obstacle_object / (vx_obstacle_object * vx_obstacle_object + vy_obstacle_object * vy_obstacle_object)

  set new-heading round-to (atan new-dx new-dy) angle-precision
end

; Determine Overlap
to-report overlap [ obstacle-or-object ]
  report (size + [size] of obstacle-or-object) / 2 - distance obstacle-or-object
end

;Randomly placing object and obstacle inside the world
to place-randomly-inside-world
  set xcor min-pxcor - 0.5 + size / 2 + random-float (world-width - size)
  set ycor min-pycor - 0.5 + size / 2 + random-float (world-height - size)
end

to-report round-to [ x p ]
  report round (x * p) / p
end

; Functionality to drag and change position of object or obstacle if mouse click is closer to center or only the size of obstacle if
; mouse click is closer to edge of the obstacle
to change-position-size
  ifelse mouse-down? [
    ifelse target-object-or-obstacle = nobody [
      ask min-one-of turtles [ min list (distancexy mouse-xcor mouse-ycor) (edge-distancexy mouse-xcor mouse-ycor) ] [
        let edge-distance edge-distancexy mouse-xcor mouse-ycor
        let center-dist distancexy mouse-xcor mouse-ycor
        if edge-distance < 1 or center-dist < size / 2 [
          set target-object-or-obstacle self
          ifelse center-dist < edge-distance or edge-distance > 1 [
            set set-target-value [[x y] ->
              ; ignore if x and y outside the world
              carefully [ setxy x y ] []
            ]
            set get-target-value [[x y] -> (word "Position: " xcor ", " ycor)]
          ][
            ifelse breed = objects [
              set set-target-value [[x y] -> set heading towardsxy x y]
              set get-target-value [[x y] -> (word "Facing: " x ", " y)]
            ] [
              set set-target-value [[x y] -> set size round-to (2 * (distancexy mouse-xcor mouse-ycor)) 10]
              set get-target-value [[x y] -> (word "Size: " size) ]
            ]
          ]
        ]
      ]
    ][
      if mouse-inside? [
        ask target-object-or-obstacle [
          (run set-target-value (round-to mouse-xcor 10) (round-to mouse-ycor 10))
          set label (runresult get-target-value (round-to mouse-xcor 10) (round-to mouse-ycor 10))
          set target-value label
        ]
        display
      ]
    ]
  ][
    reset-dragging
  ]
end

to-report edge-distancexy [ x y ]
  report abs (size / 2 - distancexy x y)
end

to reset-dragging
  if is-turtle? target-object-or-obstacle [
    ask target-object-or-obstacle [
      set label ""
    ]
  ]
  set target-object-or-obstacle nobody
  set set-target-value [ -> ]
  set get-target-value [ -> 0 ]
  set target-value ""
end
@#$#@#$#@
GRAPHICS-WINDOW
335
10
773
449
-1
-1
25.3
1
10
1
1
1
0
0
0
1
-8
8
-8
8
1
1
1
ticks
30.0

BUTTON
10
255
185
288
NIL
setup-random
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
10
300
185
333
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SWITCH
10
205
180
238
trace-path?
trace-path?
0
1
-1000

BUTTON
10
350
185
383
NIL
clear-drawing
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
10
10
180
43
num-obstacles
num-obstacles
0
10
2.0
1
1
NIL
HORIZONTAL

BUTTON
10
395
185
428
NIL
change-position-size
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
10
160
182
193
num-objects
num-objects
0
50
5.0
1
1
NIL
HORIZONTAL

SLIDER
10
60
182
93
meeting-radius
meeting-radius
0
15
1.0
1
1
NIL
HORIZONTAL

SLIDER
10
115
182
148
object-color
object-color
5
11
9.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
This model is basically a collision model where there are objects and obstacles.
Objects can collide with Obstacles and other objects.

The user can choose the number of objects and obstacles using num-obstacles and num-objects.

trace-path will determine whether path of objects will be traced.

setup-random ->All objects and obstacles are placed randomly inside the world. Objects are placed such that they cannot overlap with obstacles initially.

go-> will start the motion of objects indefinitely.

clear-drawing -> It will clear the path drawn of objects.

drag -> Using drag, the user can move the object and obstacle by clicking on the center of object or obstacle. Also, by clicking on the edge of the obstacle, user can change the size of the obstacle.

All objects will be of different shape. Color of objects will be determined by user using object-color value.

The user can also determine meeting-radius to determine the radius of meeting with another object. If other object is within the radius, collision will happen.


Created this model by using Chaos in a Box model as reference.
Head, B. and Wilensky, U. (2017). NetLogo Chaos in a Box model. http://ccl.northwestern.edu/netlogo/models/ChaosinaBox. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

circle-with-border
false
15
Circle -7500403 true false 0 0 300
Circle -1 true true 15 15 270

circled-default
true
0
Circle -7500403 true true 2 2 297
Polygon -1 true false 150 5 40 250 150 205 260 250

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
setup-periodic-quilt
repeat 1000 [ go ]
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@

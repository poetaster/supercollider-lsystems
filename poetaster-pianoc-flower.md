#  Peano-c flower after Gary Teachout

The simplified form of axiom and rules (without color):

```
axiom: FXFXFX
rules:
 F => 
 X =>  [FX-FY][-FX-FY-FX][ZZ]-FY-FX+FY+FX
 Y => FY
 Z => -FX-FY-FX
```

![Peano-c Flower](poetaster-pianoc-flower.svg)

# supercollider audio rendering

![Peano-c Flower](poetaster-pianoc-flower.scd)

## link to render 

https://anvaka.github.io/lsystem/?code=%2F%2F%20Pean-c%20flower%20after%20Gary%20Teachout%0Aaxiom%3A%20FXhFXiFX%0Arules%3A%0A%20F%20%3D%3E%20%0A%20X%20%3D%3E%20%20%5BFX-FY%5D%5B-cFX-FY-FX%5D%5BZZ%5D-dFY-FX%2BFY%2BFX%0A%20Y%20%3D%3E%20FY%0A%20Z%20%3D%3E%20-cFX-FY-FX%0A%0Acolor%3A%20green%0Adepth%3A%202%0Aangle%3A%20340%0Awidth%3A%202%0Adirection%3A%20%5B1%2C1%2C1%5D%0Aactions%3A%0A%20%20c%20%3D%3E%20setColor%28%22violet%22%29%0A%20%20d%20%3D%3E%20setColor%28%22lime%22%29%0A%20%20h%20%3D%3E%20rotate%285%29%0A%20%20i%20%3D%3E%20rotate%28-3%29

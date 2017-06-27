# postcss-bounce

PostCSS plugin for creating spring-based keyframe animations. Adds the `bounce`, `bounce-from` and `bounce-to` properties:

```css
.square
    width: 100px
    height: 100px
    background: red
    bounce: 1.0s
    bounce-from: transform: scale(0.2) translate(200px, 0px)
    bounce-to: transform: scale(1) translate(0px, 100px)
```

![](https://i.imgur.com/U7zq9KG.gif)

## TODO

* Keep initial transform if no bounce-from is givn
* Support other value interpolations (percents, colors)
* Spring constant as parameter

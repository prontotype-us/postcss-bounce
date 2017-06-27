postcss = require 'postcss'

# Spring interpolation
# ------------------------------------------------------------------------------

springEq = (t, p=0.5) -> # T is 0 to 1
    Math.pow(2, -10 * t) * Math.sin((t - p / 4) * (2 * Math.PI) / p) + 1

# Stringifying
# ------------------------------------------------------------------------------

valueToString = ({type, value}) ->
    value_string = value.toFixed(2)
    if type == 'px'
        value_string += 'px'
    else if type == 'pct'
        value_string += '%'
    return value_string

transformToString = ({type, values}) ->
    return type + '(' + values.map(valueToString).join(', ') + ')'

transformsToString = (transforms) ->
    transforms
        .map ({type, values}) ->
            return type + '(' + values.map(valueToString).join(', ') + ')'
        .join(' ')

# Interpolation
# ------------------------------------------------------------------------------

interpolateValue = (start_value, end_value, position) ->
    interpolated_value = (end_value.value - start_value.value) * position + start_value.value
    {type: start_value.type, value: interpolated_value}
    # "translate(#{interpolated.toFixed(1)}px, 0)"

interpolateTransform = (from_transform, to_transform, position) ->
    interpolated_transform = {
        type: from_transform.type
        values: []
    }
    [0...from_transform.values.length].map (vi) ->
        interpolated_transform.values.push interpolateValue \
            from_transform.values[vi], to_transform.values[vi], position
    return interpolated_transform

interpolateTransforms = (from_transforms, to_transforms, position) ->
    # This has to assume tne transforms are in the same order for both
    interpolated_transforms = {
        type: 'transform'
        values: []
    }
    [0...from_transforms.values.length].map (vi) ->
        interpolated_transforms.values.push interpolateTransform \
            from_transforms.values[vi], to_transforms.values[vi], position
    return interpolated_transforms

parseTransform = (raw_transform) ->
    type = raw_transform.match(/(\w+)\([^\)]+\)/)[1]
    inner_transform = raw_transform.match(/\w+\(([^\)]+)\)/)[1]
    values = inner_transform.split(',')
        .map (s) -> s.trim()
        .map parseValue
    {type, values}

parseTransforms = (raw_transforms) ->
    transform_matches = raw_transforms.match /\w+\([^\)]+\)/g
    ret = transform_matches.map parseTransform
    return ret

parseValue = (raw_value) ->
    is_px = raw_value.match /px$/
    is_pct = raw_value.match /%$/
    if is_px
        type = 'px'
        value = Number raw_value.replace /px$/, ''
    else if is_pct
        type = 'pct'
        value = Number raw_value.replace /%$/, ''
    else
        type = 'number'
        value = Number raw_value
    {type, value}

parseDeclValue = (decl_value) ->
    [type, value] = decl_value.split(':')
    if type == 'transform'
        values = parseTransforms value
        return {type, values}
    else
        value = parseValue value
        return {type, value}

# Main plugin
# ------------------------------------------------------------------------------

module.exports = postcss_bounce = (css) ->
    bounces = 0

    css.walkDecls (decl) ->
        if decl.prop == 'bounce'

            # TODO: Create unique bounce keyframes name
            keyframes_name = 'bounce' + bounces
            bounces += 1

            # Change node to animate
            decl.prop = 'animation'
            decl.value = keyframes_name + ' ' + decl.value + ' forwards'

            # Find and delete bounce-from, to
            bounce_from = null
            bounce_to = null
            decl.parent.walkDecls (decl) ->
                if decl.prop == 'bounce-from'
                    bounce_from = decl.value
                    decl.remove()
                if decl.prop == 'bounce-to'
                    bounce_to = decl.value
                    decl.remove()

            # Add keyframes
            at_rule = postcss.atRule
                name: 'keyframes'
                params: keyframes_name

            parsed_from = parseDeclValue bounce_from
            parsed_to = parseDeclValue bounce_to

            end_position = 200
            start_position = 50

            n_percents = 5
            [0..n_percents].map((n) -> n * 100/n_percents).map (percent) ->
                rule = postcss.rule
                    selector: percent + '%'

                position = springEq percent/100
                position = 1 if percent == 100

                if parsed_from.type == 'transform'
                    interpolated_transforms = interpolateTransforms(parsed_from, parsed_to, position)
                    interpolated_decl =
                        prop: 'transform'
                        value: transformsToString interpolated_transforms.values
                else
                    interpolated_value = interpolateValue(parsed_from.value, parsed_to.value, position)
                    interpolated_decl =
                        prop: parsed_from.type
                        value: valueToString interpolated_value

                position_decl = postcss.decl interpolated_decl
                rule.append(position_decl)
                at_rule.append(rule)

            css.prepend at_rule

    return css


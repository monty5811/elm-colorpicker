module ColorPicker exposing (State, Msg, empty, update, view, color2Hex, hex2Color)

{-| An Elm library to help you implement a color picker tool.

@docs State, Msg, empty, update, view, color2Hex, hex2Color

-}

import Color exposing (Color)
import Hex
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events
import Json.Decode as Decode exposing (..)
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)


widgetWidth =
    200


{-| Opaque type. Needs to be added to your model. You will also need to store a `Color` in your model

    type alias Model =
        { myColour : Color
        , colorPicker : ColorPicker.Model
        }

-}
type State
    = State Model


{-| Initial ColorPicker state

    init =
        { myColour = Color.red
        , colorPicker = ColorPicker.empty
        }

-}
empty : State
empty =
    State blankModel


{-| The model stores the hsl details as converting to/from hex all the time.
But the user could easily change their hex between updates so we need to check that this has _probably_
not happened.
-}
type alias Model =
    { pickerMouseDown : Bool
    , hueSliderMouseDown : Bool
    , opacitySliderMouseDown : Bool
    , hue : Float -- 0.1 .. 1.0
    }


blankModel : Model
blankModel =
    { pickerMouseDown = False
    , hueSliderMouseDown = False
    , opacitySliderMouseDown = False
    , hue = 0.5
    }


{-| Opaque type. These messages are handled by `ColorPicker.update`
-}
type Msg
    = PickerClick ( Int, Int )
    | PickerMouseDown Bool
    | OnHueChange ( Int, Int )
    | OnOpacityChange ( Int, Int )
    | OnHueMouseDown Bool
    | OnOpacityMouseDown Bool
    | NoOp


{-| On each update, ColorPicker returns its model and (where appropriate) the new selected colo(u)r.

    ColorPickermsg msg ->
        let
            (cp, col) =
                ColorPicker.update msg model.colorPicker
        in
            { model | colorPicker = cp, myColor = Maybe.withDefault model.myColor col }

-}
update : Msg -> Color -> State -> ( State, Maybe Color )
update message col (State model) =
    case message of
        PickerClick ( x, y ) ->
            let
                { hue } =
                    safeToHsl model.hue col

                newColour =
                    Color.hsl hue (toFloat x / widgetWidth) (1 - toFloat y / 150)
            in
            ( State model, Just newColour )

        PickerMouseDown val ->
            ( State { model | pickerMouseDown = val }, Nothing )

        OnHueChange ( x, _ ) ->
            let
                ( state, newColour ) =
                    handleHueChange x col model
            in
            ( State state, Just newColour )

        OnHueMouseDown val ->
            ( State { model | hueSliderMouseDown = val }, Nothing )

        OnOpacityChange ( x, _ ) ->
            ( State model, Nothing )

        _ ->
            ( State model, Nothing )


handleHueChange : Int -> Color -> Model -> ( Model, Color )
handleHueChange x col model =
    let
        { saturation, lightness } =
            safeToHsl model.hue col

        hue =
            toFloat x / widgetWidth

        -- * 2 * pi
        newColour =
            -- Enable 'escape from black'
            if saturation == 0 && lightness < 0.02 then
                Color.hsl hue 0.5 0.5

            else
                Color.hsl hue saturation lightness
    in
    ( { model | hue = hue }, newColour )


{-| Renders the color picker on screen
-}
view : Color -> State -> Html Msg
view col (State model) =
    let
        colCss =
            Color.hsl model.hue 1 0.5
                |> Color.toCssString
    in
    div
        [ Attr.style "background-color" "white"
        , Attr.style "padding" "6px"
        , Attr.style "display" "inline-block"
        , Attr.style "border-radius" "5px"
        , Attr.style "box-shadow" "rgba(0, 0, 0, 0.15) 0px 0px 0px 1px, rgba(0, 0, 0, 0.15) 0px 8px 16px"
        , Attr.class "color-picker-container"
        , bubblePreventer
        ]
        [ div pickerStyles
            [ satLightPalette colCss model
            , pickerIndicator model.hue col
            ]
        , div (pickerStyles ++ sliderContainerStyles "hue")
            [ huePalette model
            , hueMarker model.hue col
            ]
        , div (checkedBkgStyles ++ pickerStyles ++ sliderContainerStyles "opacity")
            [ opacityPalette colCss model
            , hueMarker 0.5 col
            ]
        ]


satLightPalette : String -> Model -> Svg Msg
satLightPalette colCss model =
    svg
        [ width (String.fromInt widgetWidth)
        , height "150"
        , class "main-picker"
        , display "block"
        ]
        [ defs
            []
            [ linearGradient
                [ id "pickerSaturation" ]
                [ stop [ offset "0", stopColor "#808080", stopOpacity "1" ] []
                , stop [ offset "1", stopColor "#808080", stopOpacity "0" ] []
                ]
            , linearGradient
                [ id "pickerBrightness", x1 "0", y1 "0", x2 "0", y2 "1" ]
                [ stop [ offset "0", stopColor "#fff", stopOpacity "1" ] []
                , stop [ offset "0.499", stopColor "#fff", stopOpacity "0" ] []
                , stop [ offset "0.5", stopColor "#000", stopOpacity "0" ] []
                , stop [ offset "1", stopColor "#000", stopOpacity "1" ] []
                ]
            ]
        , rect [ width (String.fromInt widgetWidth), height "150", fill colCss, id "picker" ] []
        , rect [ width (String.fromInt widgetWidth), height "150", fill "url(#pickerSaturation)" ] []
        , rect
            ([ width (String.fromInt widgetWidth)
             , height "150"
             , fill "url(#pickerBrightness)"
             ]
                ++ dragAttrs model.pickerMouseDown PickerMouseDown PickerClick
            )
            []
        ]


{-| pick saturation & lightness
-}
pickerIndicator : Float -> Color -> Html Msg
pickerIndicator hue col =
    let
        { saturation, lightness } =
            safeToHsl hue col

        borderColor =
            if lightness > 0.95 then
                "#cccccc"

            else
                "#ffffff"

        cx_ =
            saturation * widgetWidth - 3 |> round |> String.fromInt

        cy_ =
            150 - lightness * 150 - 3 |> round |> String.fromInt
    in
    div
        [ Attr.style "position" "absolute"
        , Attr.style "top" (cy_ ++ "px")
        , Attr.style "left" (cx_ ++ "px")
        , Attr.style "border-radius" "100%"
        , Attr.style "border" ("2px solid " ++ borderColor)
        , Attr.style "width" "6px"
        , Attr.style "height" "6px"
        , Attr.style "pointer-events" "none"
        ]
        []



-- --------------------------
-- HUE
-- --------------------------


huePalette : Model -> Svg Msg
huePalette { hueSliderMouseDown } =
    let
        mkStop ( os, sc ) =
            stop [ offset os, stopColor sc, stopOpacity "1" ] []

        stops : List ( String, String )
        stops =
            [ ( "0%", "#FF0000" )
            , ( "17%", "#FF00FF" )
            , ( "33%", "#0000FF" )
            , ( "50%", "#00FFFF" )
            , ( "66%", "#00FF00" )
            , ( "83%", "#FFFF00" )
            , ( "100%", "#FF0000" )
            ]
    in
    svg
        (class "hue-picker" :: sliderStyles)
        [ defs []
            [ linearGradient
                [ id "gradient-hsv", x1 "100%", y1 "0%", x2 "0%", y2 "0%" ]
                (stops |> List.map mkStop)
            ]
        , rect
            ([ x "0"
             , y "0"
             , width (String.fromInt widgetWidth)
             , height "100%"
             , fill "url(#gradient-hsv)"
             ]
                ++ dragAttrs hueSliderMouseDown OnHueMouseDown OnHueChange
            )
            []
        ]



-- --------------------------
-- OPACITY
-- --------------------------


opacityPalette : String -> Model -> Svg Msg
opacityPalette colCss { opacitySliderMouseDown } =
    let
        mkStop ( os, sc, op ) =
            stop [ offset os, stopColor sc, stopOpacity op ] []

        stops : List ( String, String, String )
        stops =
            [ ( "0%", colCss, "1" )
            , ( "100%", colCss, "0" )
            ]
    in
    svg sliderStyles
        [ defs []
            [ linearGradient
                [ id "gradient-opacity", x1 "100%", y1 "0%", x2 "0%", y2 "0%" ]
                (stops |> List.map mkStop)
            ]
        , rect
            ([ x "0"
             , y "0"
             , width (String.fromInt widgetWidth)
             , height "100%"
             , fill "url(#gradient-opacity)"
             ]
                ++ dragAttrs opacitySliderMouseDown OnOpacityMouseDown OnOpacityChange
            )
            []
        ]


{-| Select the hue
-}
hueMarker : Float -> Color -> Html Msg
hueMarker lastHue col =
    let
        { hue } =
            safeToHsl lastHue col

        correction =
            4

        xVal =
            -- shift by 4px to center on selected color
            (hue * widgetWidth - correction) |> round |> String.fromInt
    in
    div (Attr.style "left" (xVal ++ "px") :: markerAttrs) []


dragAttrs : Bool -> (Bool -> Msg) -> (( Int, Int ) -> Msg) -> List (Svg.Attribute Msg)
dragAttrs mouseDown mouseDownMsg clickMsg =
    let
        common =
            [ onMouseDown (mouseDownMsg True)
            , onMouseUp (mouseDownMsg False)
            , onClickSvg clickMsg
            ]
    in
    if mouseDown then
        onMouseMovePos clickMsg :: common

    else
        onMouseOut (mouseDownMsg False) :: common



-- Styles


sliderContainerStyles name =
    [ Attr.style "width" (String.fromInt widgetWidth ++ "px")
    , Attr.style "height" "12px"
    , Attr.style "marginTop" "8px"
    , Attr.class <| "color-picker-slider " ++ name
    ]


checkedBkgStyles =
    [ Attr.style "background-size" "12px 12px"
    , Attr.style "background-position" "0 0, 0 6px, 6px -6px, -6px 0px"
    , Attr.style "background-image" "linear-gradient(45deg, #808080 25%, transparent 25%), linear-gradient(-45deg, #808080 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #808080 75%), linear-gradient(-45deg, transparent 75%, #808080 75%)"
    ]


sliderStyles =
    [ width (String.fromInt widgetWidth)
    , height "100%"
    , display "block"
    ]


pickerStyles : List (Html.Attribute msg)
pickerStyles =
    [ Attr.style "cursor" "crosshair"
    , Attr.style "position" "relative"
    ]


markerAttrs =
    [ Attr.style "position" "absolute"
    , Attr.style "top" "1px"
    , Attr.style "bottom" "1px"
    , Attr.style "border" "1px solid #ddd"
    , Attr.style "background-color" "#ffffff"

    -- , Attr.style "height" "10px"
    , Attr.style "width" "6px"

    -- this is essental to enable dragging
    , Attr.style "pointer-events" "none"
    ]


{-| Hack to prevent SVG click events bubble through to rest of app. SVG does not have an onWithOptions
-}
bubblePreventer : Html.Attribute Msg
bubblePreventer =
    -- stopPropagationOn "click" <| Decode.succeed ( NoOp, True )
    stopPropagationOn "click" <| Decode.fail "dont do more"


onMouseMovePos : (( Int, Int ) -> Msg) -> Svg.Attribute Msg
onMouseMovePos msgCreator =
    on "mousemove" (Decode.map msgCreator decodePoint)


decodePoint : Decoder ( Int, Int )
decodePoint =
    map2 (\a b -> ( a, b ))
        (field "offsetX" Decode.int)
        (field "offsetY" Decode.int)


onClickSvg : (( Int, Int ) -> Msg) -> Svg.Attribute Msg
onClickSvg msgCreator =
    on "click" (Decode.map msgCreator decodePoint)



-- Colour Helpers


{-| Converts `Color` to `String` (with preceding `#`).
Used internally and exposed because the public alternative is a library with multiple dependencies.
-}
color2Hex : Color -> String
color2Hex col =
    let
        { red, green, blue } =
            Color.toRgba col
    in
    [ red, green, blue ]
        |> List.map ((*) 255 >> round >> padHex)
        |> String.join ""
        |> (++) "#"


{-| Converts `String` to `Color`.
Used internally and exposed because the public alternative is a library with multiple dependencies.
-}
hex2Color : String -> Maybe Color
hex2Color s =
    let
        hex =
            String.toLower s

        conv begin end =
            String.slice begin end >> Hex.fromString >> Result.map toFloat
    in
    if String.length s /= 7 then
        Nothing

    else
        Result.map3 Color.rgb (conv 1 3 hex) (conv 3 5 hex) (conv 5 7 hex)
            |> Result.toMaybe


{-| Converts colour to
-}
safeToHsl : Float -> Color -> { hue : Float, saturation : Float, lightness : Float, alpha : Float }
safeToHsl lastHue col =
    let
        ({ hue, saturation, lightness, alpha } as hsl) =
            Color.toHsla col

        hue_ =
            -- TODO if hue is close enough to lastHue then
            lastHue
    in
    { hue = hue_, saturation = saturation, lightness = lightness, alpha = alpha }


padHex : Int -> String
padHex x =
    if x < 16 then
        "0" ++ Hex.toString x

    else
        Hex.toString x

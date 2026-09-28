extension Config {
    /// The bundled config: ~/.config/kanata/kanata.kbd on the TOTEM grid
    /// (3x5 + outer column + thumbs), zmk's sym-row macros where kanata has
    /// Cmd+Ctrl+Alt app shortcuts.
    public static let defaultSource = #"""
        ;; totem: kanata on the iPad.
        ;;
        ;; Same syntax as kanata. defsrc lays out the touch grid: one line per row,
        ;; `gap:w` leaves space, `name:w` makes a key w units wide. Layers list
        ;; keys in defsrc order, without the gaps.
        ;;
        ;; An iOS keyboard can only insert text, delete and move the cursor, so:
        ;;   * letters, symbols, tab, ret, space, bspc and del work everywhere
        ;;   * A-bspc / M-bspc, A-del, arrows, A-/M-arrows, home, end are emulated
        ;;   * M-c M-x M-v copy, cut and paste (needs Full Access); M-z / M-S-z undo
        ;;     and redo what this keyboard typed
        ;;   * the `term` key switches to terminal mode, where C-x, A-x, esc,
        ;;     arrows and f1-f12 send control codes and escape sequences
        ;;     (Blink, SSH apps)
        ;;   * other Cmd chords, selection (S-arrows) and media keys draw dimmed;
        ;;     iOS gives keyboards no way to send them. The kanata slots that
        ;;     held ⌘A ⌘S ⌘D ⌘F ⌘G carry sticky modifiers and rpt here.
        ;;
        ;; Extra actions: nextkbd (globe), dismiss, term, copy, cut, paste,
        ;; (text "..."), (swipe-cursor a) and (swipe-delete a): `a` on tap and
        ;; hold, a drag moves the cursor or deletes words instead. switch also
        ;; takes (mode text) and (mode terminal).

        (defcfg
          repeat-delay 400
          repeat-interval 50
          terminal-mode no
          height-phone 240
          height-tablet 320
        )

        (defvar
          tap-time 300
          hold-time 170
          long-hold-time 200
          chord-time 110
          one-shot-time 2000
        )

        (defsrc
          bspc  q    w    e    r    t  y    u    i    o    p    bspr
          tab   a    s    d    f    g  h    j    k    l    ;    ret
          lsft  z    x    c    v    b  n    m    ,    .    /    rsft
          fn    lalt lmet spc:6                             rmet ralt menu
        )

        (defalias
          .   (fork . S-; (lsft rsft))
          ,   (fork , (unshift ;) (lsft rsft))
          pr  (fork S-0 S-, (lsft rsft))
          pl  (fork S-9 S-. (lsft rsft))
          {   S-[
          }   S-]
          <   S-,
          >   S-.
          ~   S-`
          ''  S-'
          -   -
          =   =
          +   S-=
          \   \
          |   S-\
          !   S-1
          @   S-2
          #   S-3
          $   S-4
          %   S-5
          ^   S-6
          &   S-7
          *   S-8

          la  (macro S-, -)
          ra  (macro - S-.)
          leq (macro S-, =)
          geq (macro = S-.)
          ceq (macro S-; =)


          und M-z
          cut M-x
          cpy M-c
          pst M-v
          rdo M-S-z

          bsp (fork bspc (unshift del) (lsft rsft))
          bwd (fork A-bspc (multi lalt (unshift del)) (lsft rsft))
          tab (switch
            (lmet rmet) f21 break
            () tab break
          )
          stb (switch
            (lmet rmet) f22 break
            () S-tab break
          )

          _cps (switch
            (lsft rsft) caps break
            () (caps-word-custom-toggle
                $one-shot-time
                (a b c d e f g h i j k l m n o p q r s t u v w x y z -)
                (0 1 2 3 4 5 6 7 8 9 bspc del up down left rght sft lsft rsft)
            ) break
          )
          cps (tap-hold $tap-time $hold-time @_cps (layer-while-held fun))

          esc (fork esc (macro esc esc) (lsft rsft))
          ;; globe: tap switches keyboard (esc in terminal mode), hold hides it
          glb (tap-hold $tap-time $hold-time
                (switch ((mode terminal)) @esc break () nextkbd break)
                dismiss)
          cag (multi lalt lctl lmet)
        )

        (defalias
          /g  (tap-hold $tap-time $hold-time / @cag)
          oss (tap-hold $tap-time $hold-time (one-shot-press $one-shot-time rsft) rsft)
          ;; nav / sym keys beside backspace and hide-keyboard: tap is sticky
          ;; (next key only), hold locks the layer; the same key unlocks
          nav (tap-hold-release $tap-time $hold-time (one-shot-press $one-shot-time (layer-while-held left)) (layer-switch left))
          sym (tap-hold-release $tap-time $hold-time (one-shot-press $one-shot-time (layer-while-held right)) (layer-switch right))
          bse (layer-switch base)
          ;; drag either backspace left to delete words back, right to delete
          ;; words forward (lift to apply); drag space to move the cursor
          bs  (swipe-delete @bsp)
          sp  (swipe-cursor spc)
          ;; inner thumb on nav / sym: sticky shift
          ssr (one-shot-press $one-shot-time rsft)
          ssl (one-shot-press $one-shot-time lsft)

          ;; nav home row: kanata has ⌘A ⌘S ⌘D ⌘F taps with fn ⌥ ⌃ ⌘ holds. A
          ;; keyboard cannot send ⌘A-⌘F, and holding a modifier plus the nav thumb
          ;; plus a key is three fingers, so these are sticky: tap, then the next
          ;; key gets it (⌥◀ word left, ⌘⌫ delete to line start, ⌃c in terminal).
          ;; Tap again to cancel. fn means nothing on iOS, so a is shift.
          osa (one-shot-press $one-shot-time lsft)
          osl (one-shot-press $one-shot-time lalt)
          osc (one-shot-press $one-shot-time lctl)
          osm (one-shot-press $one-shot-time lmet)

          'a  (tap-hold $tap-time $hold-time '  ralt)
          ''c (tap-hold $tap-time $hold-time @'' rctl)
          `m  (tap-hold $tap-time $hold-time `  rmet)
          ~h  (tap-hold-release $tap-time $long-hold-time S-` fn)

        )

        (defchordsv2
          (j k) ret $chord-time all-released (left right fun)
          (d f) @bwd $chord-time all-released (left right fun)
        )

        (deflayer base
          @bs   q    w    e    r    t         y    u    i    o    p    @bs
          tab   a    s    d    f    g         h    j    k    l    @/g  ret
          @oss  z    x    c    v    b         n    m    @,   @.   @-   @oss
          @glb     @cps  @nav @sp                            @sym @cps term
        )

        (deflayer left
          _     1    2    3    4    5         6    7    8    9    0    _
          _     @osa @osl @osc @osm rpt       left down up   rght @tab _
          _     @und @cut @cpy @pst @rdo      home pgdn pgup end  @stb _
          _        XX    @bse _                            @ssr caps _
        )

        (deflayer right
          _     @!   @@   @#   @$   @%        @^   @&   @*   @+   nextkbd _
          _     @\   @{   [    ]    @}        @=   @`m  @''c @'a  @~h  _
          _     @|   @<   @pl  @pr  @>        @la  @leq @geq @ra  @ceq _
          _        caps  @ssl _                            @bse XX   _
        )

        ;; fun: bluetooth has no meaning here, those keys stay empty
        (deflayer fun
          _     f1   f2   f3   f4   f5        f6   f7   f8   f9   f10  _
          _     XX   XX   brdn brup f11       f12  vold volu mute XX   _
          XX    XX   XX   XX   XX   XX        XX   XX   XX   XX   XX   XX
          _        _     XX   XX                            XX   _    _
        )
        """#
}

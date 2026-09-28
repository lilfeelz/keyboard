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
          gap   q    w    e    r    t  y    u    i    o    p    gap
          tab   a    s    d    f    g  h    j    k    l    ;    ret
          lsft  z    x    c    v    b  n    m    ,    .    /    rsft
          fn    lalt lmet:2    spc:4                   rmet:2    ralt menu
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

          ;; esc means nothing to a text field: hide the keyboard there instead
          esc (switch
            ((mode text)) dismiss break
            () (fork esc (macro esc esc) (lsft rsft)) break
          )
          cag (multi lalt lctl lmet)
        )

        (defalias
          /g  (tap-hold $tap-time $hold-time / @cag)
          oss (tap-hold $tap-time $hold-time (one-shot-press $one-shot-time rsft) rsft)
          ;; drag the backspace thumb left to delete words, the esc thumb to move the cursor
          lft (swipe-delete (tap-hold-release $tap-time $hold-time @bsp (layer-while-held left)))
          rgt (swipe-cursor (tap-hold-release $tap-time $hold-time @esc (layer-while-held right)))
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
                q    w    e    r    t         y    u    i    o    p
          tab   a    s    d    f    g         h    j    k    l    @/g  ret
          @oss  z    x    c    v    b         n    m    @,   @.   @-   @oss
          nextkbd  @cps  @lft      spc                 @rgt      @cps term
        )

        (deflayer left
                1    2    3    4    5         6    7    8    9    0
          _     @osa @osl @osc @osm rpt       left down up   rght @tab _
          _     @und @cut @cpy @pst @rdo      home pgdn pgup end  @stb _
          _        XX    _         _                   @ssr      caps _
        )

        (deflayer right
                @!   @@   @#   @$   @%        @^   @&   @*   @+   nextkbd
          _     @\   @{   [    ]    @}        @=   @`m  @''c @'a  @~h  _
          _     @|   @<   @pl  @pr  @>        @la  @leq @geq @ra  @ceq _
          _        caps  @ssl      _                   _         XX   _
        )

        ;; fun: bluetooth has no meaning here, those keys stay empty
        (deflayer fun
                f1   f2   f3   f4   f5        f6   f7   f8   f9   f10
          _     XX   XX   XX   XX   XX        brdn vold volu brup mute _
          f11   XX   XX   XX   XX   XX        XX   XX   XX   XX   XX   f12
          _        _     XX        XX                  XX        _    _
        )
        """#
}

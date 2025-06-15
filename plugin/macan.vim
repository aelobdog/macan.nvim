if exists('g:loaded_macan')
  finish
endif
let g:loaded_macan = 1

" Only define commands, don't auto-setup
" Users should call require('macan').setup() in their config
if has('nvim')
  lua require('macan')
endif 
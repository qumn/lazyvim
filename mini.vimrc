set leader=" "
nmap <leader>mv :vsplit<CR><C-w>h:bprev<CR>
" === norman keyboard layout
nnoremap y h
nnoremap n j
nnoremap i k
nnoremap o l

vnoremap y h
vnoremap n j
vnoremap i k
vnoremap o l

" a workaround for the fact that `i` are used up in visual mode
" vnoremap " i"
vnoremap ( i)
vnoremap [ i]
vnoremap { i}
onoremap o l
xnoremap o l
onoremap y h
xnoremap y h

noremap Y ^
noremap O $
noremap N J
" noremap I K

" map r <Nop>
noremap r i
noremap R I
noremap l o
noremap L O

noremap j y
noremap h n
noremap H N
noremap k r
noremap K R
nnoremap <c-l> <c-o>
nnoremap <c-r> <c-i>
nnoremap <c-u> <c-r>

" map for jump between windows
nnoremap <C-w>y <C-w>h
nnoremap <C-w>n <C-w>j
nnoremap <C-w>i <C-w>k
nnoremap <C-w>o <C-w>l
nnoremap <C-y> <C-w>h
nnoremap <C-n> <C-w>j
nnoremap <C-i> <C-w>k
nnoremap <C-o> <C-w>l


nnoremap go gt
nnoremap gy gT

" nnoremap <silent> <C-a> ggVG
nnoremap <silent> <leader>h :nohl<CR>
nnoremap <silent> <leader>w :w!<CR>
nnoremap <silent> <leader>q :q!<CR>

nnoremap js <plugys>
nnoremap ds <plugds>
nnoremap cs <plugcs>


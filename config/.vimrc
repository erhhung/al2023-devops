" basic vimrc adapted from: https://gist.github.com/simonista/8703722

syntax on
set nocompatible
set encoding=utf-8
set modelines=0
set ttyfast
"set number
set ruler
set visualbell
set laststatus=2
set showmode
set showcmd
set hidden
set wrap
set formatoptions=tcqrn1
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set noshiftround
set scrolloff=3
set backspace=indent,eol,start
set matchpairs+=<:>
nnoremap / /\v
vnoremap / /\v
set hlsearch
set incsearch
set ignorecase
set smartcase
set showmatch
map <leader><space> :let @/=''<cr>

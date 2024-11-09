@echo off

if exist *.fdb_latexmk del /s /q *.fdb_latexmk
if exist *.run.xml del /s /q *.run.xml
if exist *.synctex.gz del /s /q *.synctex.gz
if exist *.aux del /s /q *.aux
if exist *.log del /s /q *.log
if exist *.lof del /s /q *.lof
if exist *.bak del /s /q *.bak
if exist *.lof del /s /q *.lof
if exist *.log del /s /q *.log
if exist *.lot del /s /q *.lot
if exist *.bbl del /s /q *.bbl
if exist *.blg del /s /q *.blg
if exist *.dvi del /s /q *.dvi
if exist *.out del /s /q *.out
if exist *.brf del /s /q *.brf
if exist *.thm del /s /q *.thm
if exist *.toc del /s /q *.toc
if exist *.idx del /s /q *.idx
if exist *.ilg del /s /q *.ilg
if exist *.ind del /s /q *.ind
if exist *.bcf del /s /q *.bcf
if exist *.equ del /s /q *.equ
if exist *.fls del /s /q *.fls

echo Auxiliary files deleted
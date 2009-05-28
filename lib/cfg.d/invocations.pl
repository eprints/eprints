# invocation strings for available executables
$c->{invocation} = {
	 'convert_crop_white' => '$(convert) -crop 0x0 -bordercolor white -border 4x4 $(SOURCE) $(TARGET)',
	 'dvips' => '$(dvips) $(SOURCE) -o $(TARGET)',
	 'sendmail' => '$(sendmail) -oi -t -odb --',
	 'elinks' => '$(elinks) -dump 1 -dump-charset UTF-8 $(SOURCE) > $(TARGET)',
	 'latex' => '$(latex) $(SOURCE)',
	 'targz' => '$(gunzip) -c < $(ARC) 2>/dev/null | $(tar) xf - -C $(DIR) >/dev/null 2>&1',
	 'antiwordpdf' => '$(antiword) -a a4 -m 8859-1 $(SOURCE) > $(TARGET)',
	 'pdftotext' => '$(pdftotext) -enc UTF-8 -layout $(SOURCE) $(TARGET)',
	 'zip' => '$(unzip) 1>/dev/null 2>&1 -qq -o -d $(DIR) $(ARC)',
	 'unzip' => '$(unzip) 1>/dev/null 2>&1 -qq -o -j -d $(DIRECTORY) $(SOURCE)',
	 'cpall' => '$(cp) -pR $(SOURCE)/* $(TARGET)',
	 'wget' => '$(wget)  -r -L -q -m -nH -np --execute="robots=off" --cut-dirs=$(CUTDIRS) $(URL)',
	 'antiword' => '$(antiword) -t -f -m UTF-8 $(SOURCE) > $(TARGET)',
	 'rmall' => '$(rm) -rf $(TARGET)/*',
   };

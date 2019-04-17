# invocation strings for available executables
$c->{invocation} ||= {};
{
my %invocations = (
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
         'wget' => '$(wget) -U "Mozilla/5.0" -r -l 1 -L -q -nH -np --execute="robots=off" --cut-dirs=$(CUTDIRS) --content-disposition $(URL)',
	 'antiword' => '$(antiword) -t -f -m UTF-8 $(SOURCE) > $(TARGET)',
	 'doc2txt' => '$(perl) $(doc2txt) $(SOURCE) $(TARGET)',
	 'rmall' => '$(rm) -rf $(TARGET)/*',
	 'ffmpeg_i' => '$(ffmpeg) -i $(SOURCE)',
	 'ffmpeg_video_mp4' => '$(ffmpeg) -y -i $(SOURCE) -acodec $(audio_codec) -ac 2 -ar $(audio_sampling) -ab $(audio_bitrate) -f $(container) -vcodec $(video_codec) -r $(video_frame_rate) -b $(video_bitrate) -s $(width)x$(height) $(TARGET)',
	 'ffmpeg_video_ogg' => '$(ffmpeg) -y -i $(SOURCE) -acodec $(audio_codec) -ac 2 -ar $(audio_sampling) -ab $(audio_bitrate) -f $(container) -vcodec $(video_codec) -r $(video_frame_rate) -b $(video_bitrate) -s $(width)x$(height) $(TARGET)',
	 'ffmpeg_audio_mp4' => '$(ffmpeg) -y -i $(SOURCE) -acodec $(audio_codec) -ac 2 -ar $(audio_sampling) -ab $(audio_bitrate) -f $(container) $(TARGET)',
	 'ffmpeg_audio_ogg' => '$(ffmpeg) -y -i $(SOURCE) -acodec $(audio_codec) -ac 2 -ar $(audio_sampling) -ab $(audio_bitrate) -f $(container) $(TARGET)',
	 'ffmpeg_cell' => '$(ffmpeg) -y -i $(SOURCE) -an -f mjpeg -ss $(offset) -t 00:00:01 -r 1 -s $(width)x$(height) $(TARGET)',
	 'unoconv' => '$(unoconv) -f $(FORMAT) $(SOURCE)',
	 'txt2refs' => '$(perl) $(txt2refs) $(SOURCE) $(TARGET)',
	 'ffprobe' => '$(ffprobe) -show_streams $(SOURCE)',
);
while(my( $name, $invo ) = each %invocations)
{
	next if exists $c->{invocation}->{$name};
	$c->{invocation}->{$name} = $invo;
}
}

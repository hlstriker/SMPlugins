<?php
	
	define('KEY_TO_CHECK', 'set_to_your_special_secret_super_key');
	
	if(empty($_GET['key']) || $_GET['key'] !== KEY_TO_CHECK)
		exit;
	
	if(!isset($_FILES['file']))
		exit;
	
	$file = &$_FILES['file'];
	if(!isset($file['tmp_name']))
		exit;
	
	$buffer = @file_get_contents($file['tmp_name']);
	if($buffer === false)
		exit;
	
	$buffer = mb_convert_encoding($buffer, 'UTF-8', 'UCS-2LE');
	
	$bom = "\xEF\xBB\xBF";
	if(strpos($buffer, $bom) === 0)
		$buffer = substr($buffer, strlen($bom));
	
	echo $buffer;
	
?>
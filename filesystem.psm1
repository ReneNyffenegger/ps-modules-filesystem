set-strictMode -version latest

$winApi = add-type -name filesystem -namespace tq84 -passThru -memberDefinition '
  [DllImport("shlwapi.dll", CharSet=CharSet.Auto)]
  public static extern bool PathRelativePathTo(
     [Out] System.Text.StringBuilder pszPath,
     [In ] string pszFrom, [In ] System.IO.FileAttributes  dwAttrFrom,
     [In ] string pszTo  , [In ] System.IO.FileAttributes  dwAttrTo
);
'
function initialize-emptyDirectory {

 #
 # Create directory $directoryName
 # If it already exists, clean it
 #

   param (
      [string] $directoryName
   )

   if (test-path $directoryName) {
      try {
       #
       # Try to remove directory.
       # Use -errorAction stop so that catch block
       # is executed if unsuccessful
       #
         remove-item -recurse -force -errorAction stop $directoryName
      }
      catch {
         return $null
      }
   }

   new-item $directoryName -type directory
}

function resolve-relativePath {
 #
 # Inspired by https://get-carbon.org/Resolve-RelativePath.html
 #
 # resolve-relativepath .\dir\subdir .\dir\another\sub\dir\file.txt
 #
   param (
      [parameter (
          mandatory        = $true
       )][string                        ]  $dir  ,


      [parameter (
          mandatory        = $true
       )][string[]                     ]  $dest
   )

 #
 # The WinAPI function PathRelativePathTo requires directory separators to be backslashes:
 #
   $dir  = $dir  -replace '/', '\'
   $dest = $dest -replace '/', '\'

   $relPath = new-object System.Text.StringBuilder 260

   [string[]] $ret = @()

   foreach ($dest_ in $dest) {
      $ok = [tq84.filesystem]::PathRelativePathTo($relPath, $dir, [System.IO.FileAttributes]::Directory, $dest_, [System.IO.FileAttributes]::Normal)
      $ret += $relPath.ToString()
   }

   return $ret
}

function write-file {
 #
 # write-file C:\users\rny\test\more\test\test\test.txt "one`ntwo`nthree"
 # write-file ./foo/bar/baz/utf8.txt      "B�rlauch"
 # write-file ./foo/bar/baz/win-1252.txt  "B�rlauch`nLibert�, Fraternit�, Kamillentee"  ( [System.Text.Encoding]::GetEncoding(1252) )
 #
   param (
      [parameter (mandatory=$true)]
      [string] $file,

      [parameter (mandatory=$true)]
      [string] $content,

      [parameter (mandatory=$false)]
      [System.Text.Encoding] $enc = [System.Text.UTF8Encoding]::new($false) # UTF8 without BOM
   )

   $abs_path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file)
   $abs_dir  = $ExecutionContext.SessionState.Path.ParseParent($abs_path, $null)

   if (! (test-path $abs_dir)) {
      $null = mkdir $abs_dir
   }

   if (test-path $abs_path) {
      remove-item $abs_path
   }

   [System.IO.File]::WriteAllText($abs_path, $content, $enc)
}

function test-fileLock {
  #
  # Inspired by
  #
  # http://mspowershell.blogspot.com/2008/07/locked-file-detection.html
  #
  # Attempts to open a file and trap the resulting error if the file is already open/locked

    param (
       [parameter (mandatory=$true)]
       [string]$filePath
    )

    if (! (test-path $filePath) ) {
       return $null
    }

    $filelocked = $false
    $fileInfo = new-object System.IO.FileInfo $filePath

    trap {
        set-variable -name filelocked -value $true -scope 1
      # $fileLocked = $true
        continue
    }

    $fileStream = $fileInfo.Open( [System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None )
    if ($fileStream) {
        $fileStream.Close()
    }

    $fileLocked
}

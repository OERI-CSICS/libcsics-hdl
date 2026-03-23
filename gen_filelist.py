
import subprocess


# run find rtl/ -name "*.sv" > filelist.f

def main():
    with open("filelist.f", "w") as f:
        subprocess.run(["find", "rtl/", "-name", "*.sv"], stdout=f)

if __name__ == "__main__":
    main()

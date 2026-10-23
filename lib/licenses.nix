{ lib }:
lib.mapAttrs
  (
    shortName:
    {
      fullName,
      url,
      redistributable ? false,
    }:
    {
      inherit
        fullName
        redistributable
        shortName
        url
        ;

      free = false;
    }
  )
  {
    alibaba-font-license = {
      fullName = "《阿里巴巴普惠体3.0版》法律声明";
      url = "https://www.yuque.com/yiguang-wkqc2/puhuiti/nus9wiinq4aeiegy";
    };

    alimama-agile-license = {
      fullName = "《alimama agile》阿里妈妈灵动体法律声明";
      url = "https://www.yuque.com/alimama_ai-font/vfse9w/xglmbv486ixncb9k";
    };

    alimama-daoliti-license = {
      fullName = "《阿里妈妈刀隶体》法律声明";
      url = "https://www.yuque.com/alimama_ai-font/vfse9w/ynqpf9pt8wops4sl";
    };

    alimama-dongfangdakai-license = {
      fullName = "《阿里妈妈东方大楷》法律声明";
      url = "https://www.yuque.com/alimama_ai-font/vfse9w/lwpwexz8c2tf4ebi";
    };

    alimama-fangyuanti-license = {
      fullName = "《阿里妈妈方圆体》法律声明";
      url = "https://www.yuque.com/alimama_ai-font/vfse9w/fco5g1gifud8lls2";
    };

    alimama-shuheiti-license = {
      fullName = "《阿里妈妈数黑体1.0版法律声明》";
      url = "https://www.yuque.com/alimama_ai-font/vfse9w/msvuh9i9895org09";
    };

    foundertype-commercial-license = {
      fullName = "方正字库“商业发布”授权说明";
      url = "https://www.foundertype.com/index.php/About/powerbus.html";
    };

    foundertype-family-license = {
      fullName = "方正字库家庭版用户许可协议";
      url = "https://www.foundertype.com/index.php/About/powerPer.html";
    };

    harmonyos-sans-fonts-license = {
      fullName = "HarmonyOS Sans Fonts License Agreement";
      url = "https://raw.gitcode.com/openharmony/global_system_resources/raw/a52632e5d3901cc860b87fe923142077de194b42/LICENSE_Fonts";
    };

    justfont-elffont-license = {
      fullName = "做作的Daphne 與 justfont《精靈文》字型授權規範";
      url = "https://github.com/justfont/Elffont/blob/3a5148e11b6636eda95d9564358560f05a0bc7a9/LICENSE";
    };

    justfont-snailfont-license = {
      fullName = "田文社與 justfont《螺體》字型授權規範";
      url = "https://github.com/justfont/Snailfont/blob/7c184e8045cbde5b39818717cc5042695ae01e17/LICENSE.txt";
    };

    microsoft-software-license = {
      fullName = "Microsoft Software License Terms";
      url = "https://support.microsoft.com/en-us/teams/platform/microsoft-software-license-terms";
    };

    mi-sans-font-license = {
      fullName = "MiSans字体知识产权许可协议";
      url = "https://hyperos.mi.com/font-download/MiSans字体知识产权许可协议.pdf";
    };

    taobao-maicaiti-license = {
      fullName = "《淘宝买菜体》法律声明";
      url = "https://share.note.youdao.com/ynoteshare/index.html?id=fa22a692c9e377cb71c025f2a71d1e3d";
    };

    tianheng-font-license = {
      fullName = "天珩字库协议";
      url = "http://cheonhyeong.com/Simplified/download.html";
    };

    tsangertype-font-license = {
      fullName = "仓耳字库字体授权";
      url = "https://tsanger.cn/";
    };

    tsangertype-freefont-license = {
      fullName = "仓耳字库免费开源字体授权申明";
      redistributable = true;
      url = "https://tsanger.cn/%E4%BB%93%E8%80%B3%E5%AD%97%E5%BA%93%E5%85%8D%E8%B4%B9%E5%95%86%E7%94%A8%E5%AD%97%E4%BD%93%E6%8E%88%E6%9D%83%E5%A3%B0%E6%98%8E.pdf";
    };
  }

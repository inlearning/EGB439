classdef PiBot < handle
 
    properties(Access = public)
        TCP_MOTORS;
        TCP_CAMERA;
    end
 
    properties (Access = private, Constant)
        TIMEOUT = 10;
 
        PORT_MOTORS = 43900; % some random ports that should be unused as they are above 2000?
        PORT_CAMERAS = 43901;
 
        IMAGE_WIDTH = 640/2;
        IMAGE_HEIGHT = 480/2;
        IMAGE_SIZE = PiBot.IMAGE_WIDTH * PiBot.IMAGE_HEIGHT * 3;
 
        FN_ARG_SEPARATOR = ','
        FN_GET_IMAGE = 'getImageFromCamera'
        FN_MOTOR_SPEEDS = 'setMotorSpeeds'
        FN_MOTOR_TICKS = 'getMotorTicks'
        FN_DISPLAY_VALUE = 'setDisplayValue'
        FN_DISPLAY_MODE = 'setDisplayMode'
    end
 
    methods
        function obj = PiBot(address)
            %PiBot.PiBot Construct a PiBot object
            %
            % PB = PiBot(IP) creates an object used for communications with the robot
            % connected via the IP address which is given as a string in dot format.
            %
            % See also PiBot.setMotorSpeeds, PiBot.getMotorTicks,
            % PiBot.setDisplayValue, PiBot.setDisplayMode.
 
            obj.TCP_MOTORS = tcpip(address, PiBot.PORT_MOTORS, 'NetworkRole', 'client', 'Timeout', PiBot.TIMEOUT);
            obj.TCP_CAMERA = tcpip(address, PiBot.PORT_CAMERAS, 'NetworkRole', 'client', 'Timeout', PiBot.TIMEOUT);
 
            % Configure the TCPIP objects
            %obj.TCP_CAMERA.Timeout = PiBot.TIMEOUT;
            %obj.TCP_MOTORS.Timeout = PiBot.TIMEOUT;
            obj.TCP_CAMERA.InputBufferSize = PiBot.IMAGE_SIZE;
 
        end
 
        function delete(obj)
            delete(obj.TCP_MOTORS);
            delete(obj.TCP_CAMERA);
        end
 
        function imgVect = getVectorFromCamera(obj)
            fopen(obj.TCP_CAMERA);
            fprintf(obj.TCP_CAMERA, [PiBot.FN_GET_IMAGE PiBot.FN_ARG_SEPARATOR '100']); 
            imgVect = fread(obj.TCP_CAMERA, PiBot.IMAGE_SIZE, 'uint8')./255;
            fclose(obj.TCP_CAMERA);
        end
         
        function img = getImageFromCamera(obj)
            img = [];
            
            % Attempt to retrieve the image
            try
                vector = obj.getVectorFromCamera();
            catch error
                warning('Empty image array returned from RPi');
                return;
            end
 
            % Convert the image to MATLAB format (if it's the correct size)
            assert(length(vector) == PiBot.IMAGE_SIZE, 'Size of data received (%d) did not match expected image size (%d). Empty image array returned!\n', length(vector), PiBot.IMAGE_SIZE);
            img = reshape([vector(1:3:end); vector(2:3:end); vector(3:3:end)],PiBot.IMAGE_WIDTH, PiBot.IMAGE_HEIGHT, 3);
        end
         
        function setMotorSpeeds(obj, varargin)
            %PiBot.setMotorSpeeds  Set the speeds of the motors
            %
            % PB.setMotorSpeeds(SA, SB) sets the speeds of the two motors to the values
            % SA and SB.
            %
            % PB.setMotorSpeeds(SPEED) sets the speeds of the two motors to the values
            % in the 2-vector SPEED = [SA SB].
            %
            % Note::
            % - This method sets the motor voltage which is somewhat correlated to
            %   rotational speed.
            
            if nargin == 2
                motors = varargin{1};
            elseif nargin == 3
                motors = [varargin{1} varargin{2}];
            else
                error('incorrect number of arguments provided');
            end
                
            assert(all(isreal(motors)), 'arguments must be real');
            assert(all(fix(motors)==motors), 'arguments must have an integer value');
            assert(all(motors>=-100 & motors<=100), 'arguments must be in the range -100 to 100');
            
            data = [PiBot.FN_MOTOR_SPEEDS];
            data = [data PiBot.FN_ARG_SEPARATOR num2str(motors(1)) PiBot.FN_ARG_SEPARATOR num2str(motors(2))];
             
            fopen(obj.TCP_MOTORS);
            fprintf(obj.TCP_MOTORS, data);
            fclose(obj.TCP_MOTORS);
        end
        
        function stop(obj)
            %PiBot.stop  Stop all motors
            %
            % PB.stop() stops all motors.
            %
            % See also PiBot.setMotorSpeed.
            
            obj.setMotorSpeeds(0, 0);
        end
 
        function ticks = getMotorTicks(obj)
        %PiBot.getMotorTicks   Get motor encoder values
        %
        % PB.getMotorTicks() returns a 2-vector containing the current encoder
        % values of the two robot motors.
        %
        % Note::
        % - The returned values have been rescaled to units of degrees.
        % - The encoder counter on the robot has a 16-bit signed value.

            data = [PiBot.FN_MOTOR_TICKS,PiBot.FN_ARG_SEPARATOR 'A']; % needed for the Pi code
            fopen(obj.TCP_MOTORS);
            fprintf(obj.TCP_MOTORS, data);
%            iter = 0;
            % We don't know the size of the file so...
%             c='';
%             s='';
%             while ~strcmp(char(c),'\n')
%                 c = ( fread(obj.TCP_MOTORS,1,'char') );
%                 s=[s c];
%                 iter = iter + 1;
%                 if iter > 30 % the tick array should never be this large, which means unsuccessful read...
%                     disp('Tick retreval timeout! (PiBot.m ~line 103) returning NULL tick value ...');
%                     pause(0.1);
%                     ticks = [];
%                     fclose(obj.TCP_MOTORS);
%                     disp('Turning all motors OFF') % this is a precaution, you can comment out this if you want
%                     setMotorSpeeds(['A','B','C','D'], [0,0,0,0]);
%                     return;
%                 end
%             end

            s = fgetl(obj.TCP_MOTORS);
            fclose(obj.TCP_MOTORS);

            % Convert ticks to numerical array
%             ticks = sscanf(s,'%f',inf);
            ticks = sscanf(s,'%d');

        end

        function setDisplayValue(obj, val)
        %PiBot.setDisplayValue  Write to the robot display
        %
        % PB.setDisplayValue(V) writes the value of V to the robot's display, using
        % the current mode.  The range of allowable values depends on the mode:
        %  - hexadecimal 0 to 255
        %  - unsigned decimal 0 to 99
        %  - signed decimal -9 to 9
        %
        % See also PiBot.setDisplayMode.
        
            assert(isreal(val), 'argument must be real');
            assert(fix(val)==val, 'argument must have an integer value');
            
            data = [PiBot.FN_DISPLAY_VALUE];
            data = [data PiBot.FN_ARG_SEPARATOR num2str(val)];
             
            fopen(obj.TCP_MOTORS);
            fprintf(obj.TCP_MOTORS, data);
            fclose(obj.TCP_MOTORS);
        end
 
        function setDisplayMode(obj, val)
        %PiBot.setDisplayMode  Set the robot display mode
        %
        % PB.setDisplayMode(M) sets the numerical mode for the robot's display:
        %  - 'x' hexadecimal
        %  - 'u' unsigned decimal
        %  - 'd' signed decimal -9 to 9
        %
        % In decimal modes the decimal point on the right-hand digit is lit.
        %
        % See also PiBot.setDisplayValue.
            data = [PiBot.FN_DISPLAY_MODE];
            data = [data PiBot.FN_ARG_SEPARATOR val];
             
            fopen(obj.TCP_MOTORS);
            fprintf(obj.TCP_MOTORS, data);
            fclose(obj.TCP_MOTORS);
        end
 
    end
end
